import Foundation
import Combine

/// 应用状态与用例编排：发布 Provider 快照、刷新状态、历史和错误，
/// 通过注入的 adapter 刷新、通过 repository 持久化。
/// 应用状态与用例编排：发布 Provider 快照、刷新状态、历史和错误，
/// 通过注入的 adapter 刷新、通过 repository 持久化。
@MainActor
final class DashboardModel: ObservableObject {
    /// 各 Provider 快照字典存储，支持动态接入扩展 Agent 快照
    @Published private(set) var providerSnapshots: [Provider: ProviderSnapshot] = [
        .codex: .empty(.codex),
        .kimiCode: .empty(.kimiCode)
    ]

    /// 兼容旧属性调用的 Codex 快照快捷访问
    var codex: ProviderSnapshot {
        get { providerSnapshots[.codex] ?? .empty(.codex) }
        set { providerSnapshots[.codex] = newValue }
    }

    /// 兼容旧属性调用的 Kimi 快照快捷访问
    var kimi: ProviderSnapshot {
        get { providerSnapshots[.kimiCode] ?? .empty(.kimiCode) }
        set { providerSnapshots[.kimiCode] = newValue }
    }

    @Published private(set) var navigation: ProviderNavigationState
    @Published private(set) var history: [DashboardSnapshot] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var lastError: String?

    // MARK: - 本地环境与工具链检测状态
    @Published private(set) var localTools: [LocalToolEnvironment] = []
    @Published private(set) var isDetectingEnv = false
    private let environmentInspector = LocalEnvironmentInspector()

    private let repository: SnapshotRepository
    private let settingsStore: ProviderSettingsStore
    private let watcherFactory: (@escaping () -> Void) -> [DirectoryWatcher]
    private let coordinator: RefreshCoordinator
    private var watchers: [DirectoryWatcher] = []

    init(
        adapters: [any UsageProviderAdapter],
        repository: SnapshotRepository,
        settingsStore: ProviderSettingsStore,
        watcherFactory: @escaping (@escaping () -> Void) -> [DirectoryWatcher],
        debounceNanoseconds: UInt64 = 1_000_000_000
    ) {
        self.repository = repository
        self.settingsStore = settingsStore
        self.watcherFactory = watcherFactory
        self.coordinator = RefreshCoordinator(
            adapters: adapters,
            debounceNanoseconds: debounceNanoseconds
        )
        self.navigation = ProviderNavigationState(preferences: settingsStore.load())
    }

    func snapshot(for provider: Provider) -> ProviderSnapshot {
        if let snap = providerSnapshots[provider] {
            return snap
        }
        return .empty(provider)
    }

    private var currentSnapshots: [Provider: ProviderSnapshot] {
        providerSnapshots
    }

    func selectProvider(_ provider: Provider) {
        navigation.selectProvider(provider)
        persistNavigation()
    }

    func setProviderEnabled(_ provider: Provider, enabled: Bool) {
        navigation.setProviderEnabled(provider, enabled)
        persistNavigation()
    }

    private func persistNavigation() {
        settingsStore.save(navigation.preferences)
    }

    func start() {
        if let persisted = repository.load() {
            codex = persisted.current.providers.first(where: { $0.provider == .codex }) ?? .empty(.codex)
            kimi = persisted.current.providers.first(where: { $0.provider == .kimiCode }) ?? .empty(.kimiCode)
            history = persisted.history
            lastRefresh = persisted.current.collectedAt
        }

        watchers = watcherFactory { [weak self] in
            Task { @MainActor [weak self] in self?.scheduleLocalRefresh() }
        }
        watchers.forEach { $0.start() }

        refresh(includeAccount: false)
        // 启动时在后台静默执行一次本地环境检测，实时同步实际已安装的 Provider 列表
        inspectEnvironment()
    }

    func stop() {
        watchers.forEach { $0.stop() }
        watchers.removeAll()
        coordinator.cancel()
    }

    /// 记录最近一次账号网络查询的发起时间，用于 30 秒防刷冷却
    private(set) var lastAccountRefreshDate: Date?

    /// 仅在打开面板或用户手动点击校准时触发账号网络查询：
    /// 1. 平时完全不触发任何网络请求；
    /// 2. 智能防刷：非 force 情况下，若距离上次查询不足 30 秒，仅刷新本地日志，避免 429 报错；
    /// 3. 用户手动点击校准时传入 force: true，无视冷却立即向远端发起查询。
    func refreshAccountOnPanelOpen(force: Bool = false) {
        let now = Date()
        if !force, let last = lastAccountRefreshDate, now.timeIntervalSince(last) < 30.0 {
            // 处于 30 秒冷却时间内，跳过网络请求，仅执行本地日志刷新
            refresh(includeAccount: false)
            return
        }

        lastAccountRefreshDate = now
        refresh(includeAccount: true)
    }

    /// 面板关闭时中断在途的账号网络请求，确保后台常驻期间绝无网络活动
    func cancelAccountRefresh() {
        coordinator.cancelAccountLane()
        isRefreshing = false
    }

    func refresh(includeAccount: Bool = true) {
        lastError = nil
        if includeAccount {
            // 账号刷新（官方接口）驱动刷新指示；本地日志统计并行刷新，
            // 解析再慢也不阻塞账号额度返回。
            isRefreshing = true
            coordinator.refresh(
                previous: currentSnapshots,
                includeAccount: true
            ) { [weak self] snapshots in
                self?.applyAccountRefresh(snapshots)
            }
        }
        coordinator.refresh(
            previous: currentSnapshots,
            includeAccount: false
        ) { [weak self] snapshots in
            self?.applyLocalRefresh(snapshots)
        }
    }

    func snapshotHistory() -> [DashboardSnapshot] { history }

    private func scheduleLocalRefresh() {
        coordinator.scheduleLocalRefresh(previous: { [weak self] in
            self?.currentSnapshots ?? [:]
        }) { [weak self] snapshots in
            self?.applyLocalRefresh(snapshots)
        }
    }

    /// 账号通道结果：只采纳账号口径字段（额度窗口、计划、账号 Token），
    /// 本机统计保持当前值，避免覆盖本地通道刚写入的数据。账号通道收尾时结束刷新指示。
    private func applyAccountRefresh(_ snapshots: [ProviderSnapshot]) {
        for snapshot in snapshots {
            var merged = self.snapshot(for: snapshot.provider)
            merged.account = snapshot.account
            merged.windows = snapshot.windows
            merged.accountUsage = snapshot.accountUsage
            merged.source = snapshot.source
            merged.errorMessage = snapshot.errorMessage
            if snapshot.status == .connected { merged.status = .connected }
            merged.collectedAt = snapshot.collectedAt
            store(merged)
        }
        finishApply(snapshots)
        isRefreshing = false
    }

    /// 本地通道结果：只采纳本机日志口径字段（token 统计、模型排行），
    /// 账号字段保持当前值。本地后台刷新不驱动刷新指示。
    private func applyLocalRefresh(_ snapshots: [ProviderSnapshot]) {
        for snapshot in snapshots {
            var merged = self.snapshot(for: snapshot.provider)
            merged.localTokenUsage = snapshot.localTokenUsage
            merged.localDailyBuckets = snapshot.localDailyBuckets
            merged.localModels = snapshot.localModels
            if snapshot.status == .connected { merged.status = .connected }
            merged.collectedAt = snapshot.collectedAt
            if merged.source == "none" { merged.source = snapshot.source }
            store(merged)
        }
        finishApply(snapshots)
    }

    private func store(_ snapshot: ProviderSnapshot) {
        providerSnapshots[snapshot.provider] = snapshot
    }

    /// 触发单次全量本地环境与工具链检测，将检测到的安装状态同步至导航与快照字典
    func inspectEnvironment() {
        guard !isDetectingEnv else { return }
        isDetectingEnv = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            let tools = await self.environmentInspector.inspectAllTools()
            self.localTools = tools

            // 筛选出本机已检测到安装的有效 Provider
            var detected: Set<Provider> = []
            for tool in tools where tool.isInstalled {
                if let provider = Provider(toolId: tool.id) {
                    detected.insert(provider)
                }
            }

            // 更新 navigation 状态中实际检测到的 Provider 列表
            self.navigation.updateDetectedProviders(detected)

            // 为检测到已安装的 Provider 初始化就绪快照（若尚未存在）
            for provider in detected {
                if self.providerSnapshots[provider] == nil {
                    var emptySnap = ProviderSnapshot.empty(provider)
                    emptySnap.status = .connected
                    emptySnap.source = "local-detected"
                    self.providerSnapshots[provider] = emptySnap
                }
            }

            self.isDetectingEnv = false
        }
    }

    private func finishApply(_ snapshots: [ProviderSnapshot]) {
        let now = Date()
        lastRefresh = now
        if let error = snapshots.compactMap(\.errorMessage).first {
            lastError = error
        }

        let snapshot = DashboardSnapshot(collectedAt: now, providers: [codex, kimi])
        // 内存中的历史与落盘保持同一 30 天裁剪规则，避免常驻期间无限增长。
        let cutoff = now.addingTimeInterval(-30 * 24 * 60 * 60)
        history.removeAll { $0.collectedAt < cutoff }
        // 目录变化触发的本地刷新可能非常频繁：历史与落盘按最小间隔节流，
        // 避免每次刷新都把整段历史重新编码写盘。
        if shouldRecordHistory(at: now) {
            history.append(snapshot)
            repository.save(current: snapshot, history: history)
        }
    }

    /// 历史快照最小记录间隔。
    private static let historyMinimumInterval: TimeInterval = 5 * 60

    private func shouldRecordHistory(at now: Date) -> Bool {
        guard let last = history.last else { return true }
        let elapsed = now.timeIntervalSince(last.collectedAt)
        // 最后一条在未来（时钟回拨等异常）时照常记录，避免历史长期停更。
        return elapsed < 0 || elapsed >= Self.historyMinimumInterval
    }
}
