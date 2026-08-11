import Foundation

/// 生产依赖组装：Provider adapter、快照仓库、设置仓库和目录监听。
/// 菜单栏入口与窗口注册留在 `App.swift`，这里只负责构造。
struct AppDependencies {
    let adapters: [any UsageProviderAdapter]
    let repository: SnapshotRepository
    let settingsStore: ProviderSettingsStore
    let watcherFactory: (@escaping () -> Void) -> [DirectoryWatcher]

    init() {
        self.adapters = [CodexProvider(), KimiProvider()]
        self.repository = JSONSnapshotRepository()
        self.settingsStore = UserDefaultsProviderSettingsStore()

        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            home.appendingPathComponent(".codex/sessions"),
            home.appendingPathComponent(".kimi-code/sessions")
        ]
        self.watcherFactory = { handler in
            roots.map { FSEventsDirectoryWatcher(rootURL: $0, handler: handler) }
        }
    }

    @MainActor
    func makeModel() -> DashboardModel {
        DashboardModel(
            adapters: adapters,
            repository: repository,
            settingsStore: settingsStore,
            watcherFactory: watcherFactory
        )
    }
}
