import Foundation

/// 刷新编排：负责目录变化防抖、本地/账号刷新分流、并发刷新合并排队与超时兜底。
/// 采集的 utility 优先级后台执行由各 adapter 内部完成，结果回到主 actor。
///
/// 账号通道（官方接口）与本地通道（本机日志）是两条独立的执行通道：
/// 互不阻塞、各自合并排队，避免本地日志解析拖住账号额度刷新。
@MainActor
final class RefreshCoordinator {
    private enum Lane {
        case account
        case local
    }

    /// 正在进行时到达的新刷新只保留最新一次，等当前刷新收尾后接着跑。
    /// 不能简单取消旧任务：采集器大多不响应取消，被取消的任务不会回调，
    /// 目录事件密集时刷新会被无限取消、刷新状态永远不结束。
    private struct PendingRefresh {
        let previous: [Provider: ProviderSnapshot]
        let onFinish: @MainActor ([ProviderSnapshot]) -> Void
    }

    private let adapters: [any UsageProviderAdapter]
    private let debounceNanoseconds: UInt64
    /// 单个 adapter 的超时兜底：adapter 卡住（如 app-server 挂起）时保留上一份数据并结束刷新，
    /// 避免刷新状态永远不结束。
    private let timeoutNanoseconds: UInt64
    private var accountTask: Task<Void, Never>?
    private var localTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var pendingAccount: PendingRefresh?
    private var pendingLocal: PendingRefresh?

    init(
        adapters: [any UsageProviderAdapter],
        debounceNanoseconds: UInt64 = 1_000_000_000,
        timeoutNanoseconds: UInt64 = 90_000_000_000
    ) {
        self.adapters = adapters
        self.debounceNanoseconds = debounceNanoseconds
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    /// 按 Provider 逐个执行 adapter 后在主 actor 回传结果；
    /// 同通道已有刷新在跑时合并为一次挂起刷新，当前任务收尾后接着执行。
    /// 不同通道（账号/本地）互不影响，并行执行。
    func refresh(
        previous: [Provider: ProviderSnapshot],
        includeAccount: Bool,
        onFinish: @escaping @MainActor ([ProviderSnapshot]) -> Void
    ) {
        let lane: Lane = includeAccount ? .account : .local
        guard task(for: lane) == nil else {
            setPending(PendingRefresh(previous: previous, onFinish: onFinish), for: lane)
            return
        }
        startRefresh(lane: lane, previous: previous, includeAccount: includeAccount, onFinish: onFinish)
    }

    private func task(for lane: Lane) -> Task<Void, Never>? {
        switch lane {
        case .account: return accountTask
        case .local: return localTask
        }
    }

    private func setTask(_ task: Task<Void, Never>?, for lane: Lane) {
        switch lane {
        case .account: accountTask = task
        case .local: localTask = task
        }
    }

    private func pending(for lane: Lane) -> PendingRefresh? {
        switch lane {
        case .account: return pendingAccount
        case .local: return pendingLocal
        }
    }

    private func setPending(_ pending: PendingRefresh?, for lane: Lane) {
        switch lane {
        case .account: pendingAccount = pending
        case .local: pendingLocal = pending
        }
    }

    private func startRefresh(
        lane: Lane,
        previous: [Provider: ProviderSnapshot],
        includeAccount: Bool,
        onFinish: @escaping @MainActor ([ProviderSnapshot]) -> Void
    ) {
        let adapters = self.adapters
        let timeout = timeoutNanoseconds
        let task = Task {
            // 各 Provider 并行刷新，整体耗时取最慢的一家而不是求和。
            let results = await withTaskGroup(of: (Int, ProviderSnapshot?).self) { group in
                for (index, adapter) in adapters.enumerated() {
                    group.addTask {
                        let prior = previous[adapter.provider] ?? .empty(adapter.provider)
                        let snapshot = await self.withTimeout(nanoseconds: timeout) {
                            await adapter.refresh(previous: prior, includeAccount: includeAccount)
                        }
                        return (index, snapshot)
                    }
                }
                var collected: [(Int, ProviderSnapshot?)] = []
                for await result in group { collected.append(result) }
                return collected.sorted { $0.0 < $1.0 }
            }
            guard !Task.isCancelled else { return }
            let snapshots: [ProviderSnapshot] = results.map { index, snapshot in
                if let snapshot { return snapshot }
                var fallback = previous[adapters[index].provider] ?? .empty(adapters[index].provider)
                fallback.errorMessage = "刷新超时，保留上次数据"
                return fallback
            }
            finish(snapshots, lane: lane, onFinish: onFinish)
        }
        setTask(task, for: lane)
    }

    private func finish(
        _ snapshots: [ProviderSnapshot],
        lane: Lane,
        onFinish: @MainActor ([ProviderSnapshot]) -> Void
    ) {
        setTask(nil, for: lane)
        onFinish(snapshots)
        if let next = pending(for: lane) {
            setPending(nil, for: lane)
            refresh(
                previous: next.previous,
                includeAccount: lane == .account,
                onFinish: next.onFinish
            )
        }
    }

    private func withTimeout<T>(
        nanoseconds: UInt64,
        operation: @escaping () async -> T
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: nanoseconds)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    /// 目录变化触发的本地刷新：防抖后只执行本地刷新，不查询账号。
    func scheduleLocalRefresh(
        previous: @escaping @MainActor () -> [Provider: ProviderSnapshot],
        onFinish: @escaping @MainActor ([ProviderSnapshot]) -> Void
    ) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            self.refresh(previous: previous(), includeAccount: false, onFinish: onFinish)
        }
    }

    /// 取消在途的账号网络请求任务（用于面板关闭时立即中断，避免多余网络开销）
    func cancelAccountLane() {
        accountTask?.cancel()
        accountTask = nil
        pendingAccount = nil
    }

    func cancel() {
        accountTask?.cancel()
        accountTask = nil
        localTask?.cancel()
        localTask = nil
        debounceTask?.cancel()
        pendingAccount = nil
        pendingLocal = nil
    }
}
