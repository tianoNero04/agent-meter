import Foundation
import Combine

/// 应用状态与用例编排：发布 Provider 快照、刷新状态、历史和错误，
/// 通过注入的 adapter 刷新、通过 repository 持久化。
@MainActor
final class DashboardModel: ObservableObject {
    @Published private(set) var codex: ProviderSnapshot = .empty(.codex)
    @Published private(set) var kimi: ProviderSnapshot = .empty(.kimiCode)
    @Published private(set) var navigation: ProviderNavigationState
    @Published private(set) var history: [DashboardSnapshot] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var lastError: String?

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
        switch provider {
        case .codex: return codex
        case .kimiCode: return kimi
        }
    }

    private var currentSnapshots: [Provider: ProviderSnapshot] {
        [.codex: codex, .kimiCode: kimi]
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
    }

    func stop() {
        watchers.forEach { $0.stop() }
        watchers.removeAll()
        coordinator.cancel()
    }

    func refresh(includeAccount: Bool = true) {
        isRefreshing = true
        lastError = nil
        coordinator.refresh(
            previous: currentSnapshots,
            includeAccount: includeAccount
        ) { [weak self] snapshots in
            self?.apply(snapshots)
        }
    }

    func snapshotHistory() -> [DashboardSnapshot] { history }

    private func scheduleLocalRefresh() {
        coordinator.scheduleLocalRefresh(previous: { [weak self] in
            self?.currentSnapshots ?? [:]
        }) { [weak self] snapshots in
            self?.apply(snapshots)
        }
    }

    private func apply(_ snapshots: [ProviderSnapshot]) {
        for snapshot in snapshots {
            switch snapshot.provider {
            case .codex: codex = snapshot
            case .kimiCode: kimi = snapshot
            }
        }

        let now = Date()
        lastRefresh = now
        isRefreshing = false
        if let error = snapshots.compactMap(\.errorMessage).first {
            lastError = error
        }

        let snapshot = DashboardSnapshot(collectedAt: now, providers: [codex, kimi])
        // 内存中的历史与落盘保持同一 30 天裁剪规则，避免常驻期间无限增长。
        let cutoff = now.addingTimeInterval(-30 * 24 * 60 * 60)
        history.removeAll { $0.collectedAt < cutoff }
        history.append(snapshot)
        repository.save(current: snapshot, history: history)
    }
}
