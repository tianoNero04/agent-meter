import Foundation
import Combine

@MainActor
final class DashboardModel: ObservableObject {
    @Published private(set) var codex: ProviderSnapshot = .empty(.codex)
    @Published private(set) var kimi: ProviderSnapshot = .empty(.kimiCode)
    @Published private(set) var navigation: ProviderNavigationState
    @Published private(set) var history: [DashboardSnapshot] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var lastError: String?

    private let snapshotStore = SnapshotStore()
    private let codexCollector = CodexLogCollector()
    private let kimiCollector = KimiLogCollector()
    private let preferences: UserDefaults
    private var watchers: [FileTreeWatcher] = []
    private var refreshTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        let enabled: Set<Provider>
        if let values = preferences.array(forKey: "enabledProviders") as? [String] {
            enabled = Set(values.compactMap(Provider.init(rawValue:)))
        } else {
            enabled = Set(Provider.allCases)
        }
        let selected = (preferences.string(forKey: "selectedProvider")).flatMap(Provider.init(rawValue:))
        navigation = ProviderNavigationState(
            enabledProviders: enabled,
            selectedProvider: selected ?? .codex
        )
    }

    func snapshot(for provider: Provider) -> ProviderSnapshot {
        switch provider {
        case .codex: return codex
        case .kimiCode: return kimi
        }
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
        preferences.set(navigation.enabledProviders.map(\.rawValue), forKey: "enabledProviders")
        preferences.set(navigation.selectedProvider?.rawValue, forKey: "selectedProvider")
    }

    func start() {
        if let persisted = snapshotStore.load() {
            codex = persisted.current.providers.first(where: { $0.provider == .codex }) ?? .empty(.codex)
            kimi = persisted.current.providers.first(where: { $0.provider == .kimiCode }) ?? .empty(.kimiCode)
            history = persisted.history
            lastRefresh = persisted.current.collectedAt
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let codexWatcher = FileTreeWatcher(rootURL: home.appendingPathComponent(".codex/sessions")) { [weak self] in
            Task { @MainActor [weak self] in self?.scheduleLocalRefresh() }
        }
        let kimiWatcher = FileTreeWatcher(rootURL: home.appendingPathComponent(".kimi-code/sessions")) { [weak self] in
            Task { @MainActor [weak self] in self?.scheduleLocalRefresh() }
        }
        watchers = [codexWatcher, kimiWatcher]
        watchers.forEach { $0.start() }

        refresh(includeAccount: false)
    }

    func stop() {
        watchers.forEach { $0.stop() }
        watchers.removeAll()
        refreshTask?.cancel()
        debounceTask?.cancel()
    }

    func refresh(includeAccount: Bool = true) {
        refreshTask?.cancel()
        isRefreshing = true
        lastError = nil

        refreshTask = Task { [weak self] in
            let localCodex = await Task.detached(priority: .utility) { CodexLogCollector().collect() }.value
            let localKimi = await Task.detached(priority: .utility) { KimiLogCollector().collect() }.value
            var accountData: CodexAccountData?
            var accountError: Error?

            if includeAccount {
                do {
                    accountData = try await CodexAppServerClient().fetch()
                } catch {
                    accountError = error
                }
            }

            guard let self else { return }
            self.apply(localCodex: localCodex, localKimi: localKimi, accountData: accountData, accountError: accountError)
        }
    }

    func snapshotHistory() -> [DashboardSnapshot] { history }

    private func scheduleLocalRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.refresh(includeAccount: false)
        }
    }

    private func apply(
        localCodex: CodexLocalData,
        localKimi: KimiLocalData,
        accountData: CodexAccountData?,
        accountError: Error?
    ) {
        let now = Date()
        let previousCodex = codex
        let codexStatus: ProviderStatus = accountData != nil || !localCodex.models.isEmpty
            ? .connected
            : previousCodex.status
        codex = ProviderSnapshot(
            provider: .codex,
            status: codexStatus,
            account: accountData?.account ?? previousCodex.account,
            windows: accountData?.windows.isEmpty == false
                ? accountData!.windows
                : (localCodex.windows.isEmpty ? previousCodex.windows : localCodex.windows),
            accountUsage: accountData?.usage ?? previousCodex.accountUsage,
            localTokenUsage: localCodex.tokenUsage,
            localModels: localCodex.models,
            source: accountData == nil
                ? (previousCodex.source == "none" ? "session-jsonl" : previousCodex.source)
                : "app-server + session-jsonl",
            collectedAt: now,
            errorMessage: accountError?.localizedDescription
        )

        kimi = ProviderSnapshot(
            provider: .kimiCode,
            status: localKimi.models.isEmpty ? .unavailable : .connected,
            account: nil,
            windows: [],
            accountUsage: nil,
            localTokenUsage: localKimi.tokenUsage,
            localModels: localKimi.models,
            source: "wire-jsonl",
            collectedAt: now,
            errorMessage: nil
        )

        lastRefresh = now
        isRefreshing = false
        if let accountError { lastError = accountError.localizedDescription }

        let snapshot = DashboardSnapshot(collectedAt: now, providers: [codex, kimi])
        history.append(snapshot)
        snapshotStore.save(current: snapshot, history: history)
    }
}
