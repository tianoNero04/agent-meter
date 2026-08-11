import Foundation

/// 刷新编排：负责任务取消、目录变化防抖、本地/账号刷新分流。
/// 采集的 utility 优先级后台执行由各 adapter 内部完成，结果回到主 actor。
@MainActor
final class RefreshCoordinator {
    private let adapters: [any UsageProviderAdapter]
    private let debounceNanoseconds: UInt64
    private var refreshTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    init(
        adapters: [any UsageProviderAdapter],
        debounceNanoseconds: UInt64 = 1_000_000_000
    ) {
        self.adapters = adapters
        self.debounceNanoseconds = debounceNanoseconds
    }

    /// 取消上一次刷新，按 Provider 逐个执行 adapter 后在主 actor 回传结果。
    func refresh(
        previous: [Provider: ProviderSnapshot],
        includeAccount: Bool,
        onFinish: @escaping @MainActor ([ProviderSnapshot]) -> Void
    ) {
        refreshTask?.cancel()
        let adapters = self.adapters
        refreshTask = Task {
            var snapshots: [ProviderSnapshot] = []
            for adapter in adapters {
                let prior = previous[adapter.provider] ?? .empty(adapter.provider)
                let snapshot = await adapter.refresh(previous: prior, includeAccount: includeAccount)
                snapshots.append(snapshot)
            }
            guard !Task.isCancelled else { return }
            onFinish(snapshots)
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

    func cancel() {
        refreshTask?.cancel()
        debounceTask?.cancel()
    }
}
