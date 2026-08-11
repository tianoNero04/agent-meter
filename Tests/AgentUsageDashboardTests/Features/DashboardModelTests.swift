import XCTest
@testable import AgentUsageDashboardKit

@MainActor
final class DashboardModelTests: XCTestCase {
    private struct Fixture {
        let model: DashboardModel
        let adapters: [FakeUsageProviderAdapter]
        let repository: FakeSnapshotRepository
        let settingsStore: FakeProviderSettingsStore
        let watchers: [FakeDirectoryWatcher]
    }

    private func makeFixture(
        persisted: PersistedDashboard? = nil,
        preferences: ProviderPreferences = ProviderPreferences()
    ) -> Fixture {
        let adapters = [
            FakeUsageProviderAdapter(provider: .codex) { previous, _ in
                var snapshot = previous
                snapshot.status = .connected
                return snapshot
            },
            FakeUsageProviderAdapter(provider: .kimiCode)
        ]
        let repository = FakeSnapshotRepository()
        repository.persisted = persisted
        let settingsStore = FakeProviderSettingsStore(preferences: preferences)
        let watchers = [FakeDirectoryWatcher(), FakeDirectoryWatcher()]

        let model = DashboardModel(
            adapters: adapters,
            repository: repository,
            settingsStore: settingsStore,
            watcherFactory: { _ in watchers }
        )
        return Fixture(
            model: model,
            adapters: adapters,
            repository: repository,
            settingsStore: settingsStore,
            watchers: watchers
        )
    }

    private func waitForRefresh(_ model: DashboardModel) async {
        for _ in 0..<200 where model.isRefreshing {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testStartRestoresPersistedStateStartsWatchersAndRunsLocalRefresh() async {
        let persistedSnapshot = DashboardSnapshot(
            collectedAt: Date(timeIntervalSince1970: 1_894_000_000),
            providers: [
                ProviderSnapshot(
                    provider: .codex,
                    status: .connected,
                    account: AccountIdentity(planType: "plus", email: nil),
                    windows: [RateLimitWindow(id: "codex", usedPercent: 31, windowMinutes: 10080, resetsAt: nil)],
                    accountUsage: nil,
                    localTokenUsage: .zero,
                    localModels: [],
                    source: "app-server + session-jsonl",
                    collectedAt: Date(timeIntervalSince1970: 1_894_000_000),
                    errorMessage: nil
                ),
                .empty(.kimiCode)
            ]
        )
        let fixture = makeFixture(persisted: PersistedDashboard(current: persistedSnapshot, history: [persistedSnapshot]))

        fixture.model.start()
        await waitForRefresh(fixture.model)

        XCTAssertEqual(fixture.model.codex.account?.planType, "plus")
        XCTAssertNotNil(fixture.model.lastRefresh)
        XCTAssertEqual(fixture.watchers.map(\.startCount), [1, 1])
        XCTAssertEqual(fixture.adapters.map(\.includeAccountValues), [[false], [false]])
        XCTAssertFalse(fixture.model.isRefreshing)
        XCTAssertEqual(fixture.repository.savedSnapshots.count, 1)
        XCTAssertGreaterThanOrEqual(fixture.model.history.count, 2)
    }

    func testRefreshWithAccountForwardsFlagAndPublishesSnapshots() async {
        let fixture = makeFixture()

        fixture.model.refresh(includeAccount: true)
        await waitForRefresh(fixture.model)

        XCTAssertEqual(fixture.adapters.map(\.includeAccountValues), [[true], [true]])
        XCTAssertEqual(fixture.model.codex.status, .connected)
        XCTAssertNotNil(fixture.model.lastRefresh)
        XCTAssertEqual(fixture.repository.savedSnapshots.count, 1)
    }

    func testAdapterErrorMessageSurfacesAsLastError() async {
        let fixture = makeFixture()
        fixture.adapters[0].handler = { previous, _ in
            var snapshot = previous
            snapshot.errorMessage = "找不到 codex 命令"
            return snapshot
        }

        fixture.model.refresh(includeAccount: true)
        await waitForRefresh(fixture.model)

        XCTAssertEqual(fixture.model.lastError, "找不到 codex 命令")
        XCTAssertEqual(fixture.model.codex.errorMessage, "找不到 codex 命令")
    }

    func testStopStopsWatchers() async {
        let fixture = makeFixture()
        fixture.model.start()
        await waitForRefresh(fixture.model)

        fixture.model.stop()

        XCTAssertEqual(fixture.watchers.map(\.stopCount), [1, 1])
    }

    func testNavigationChangesPersistThroughSettingsStore() {
        let fixture = makeFixture()

        fixture.model.selectProvider(.kimiCode)
        XCTAssertEqual(fixture.settingsStore.preferences.selectedProvider, .kimiCode)

        fixture.model.setProviderEnabled(.kimiCode, enabled: false)
        XCTAssertEqual(fixture.settingsStore.preferences.enabledProviders, [.codex])
        XCTAssertEqual(fixture.settingsStore.preferences.selectedProvider, .codex)
        XCTAssertEqual(fixture.model.navigation.selectedProvider, .codex)
        XCTAssertEqual(fixture.settingsStore.saveCount, 2)
    }

    func testNavigationFallsBackWhenPersistedSelectionIsDisabled() {
        let fixture = makeFixture(
            preferences: ProviderPreferences(enabledProviders: [.kimiCode], selectedProvider: .codex)
        )

        XCTAssertEqual(fixture.model.navigation.visibleProviders, [.kimiCode])
        XCTAssertEqual(fixture.model.navigation.selectedProvider, .kimiCode)
    }
}
