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
        // 本地后台刷新不驱动 isRefreshing，以 lastRefresh 落定为准；
        // start() 可能已从持久化状态恢复 lastRefresh，需等它变化。
        let initial = model.lastRefresh
        for _ in 0..<200 {
            if !model.isRefreshing, let lastRefresh = model.lastRefresh, lastRefresh != initial { return }
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

        // 账号刷新同时触发账号通道和本地通道，两条通道互不阻塞（调用顺序不定）。
        XCTAssertEqual(fixture.adapters.map { $0.includeAccountValues.sorted { !$0 && $1 } }, [[false, true], [false, true]])
        XCTAssertEqual(fixture.model.codex.status, .connected)
        XCTAssertNotNil(fixture.model.lastRefresh)
        XCTAssertEqual(fixture.repository.savedSnapshots.count, 1)
    }

    func testAccountRefreshEndsSpinnerWithoutWaitingForLocalLogs() async throws {
        let fixture = makeFixture()
        // 本地日志解析慢（500ms），账号接口即刻返回：转圈只等账号通道。
        fixture.adapters[0].delayNanoseconds = 500_000_000
        fixture.adapters[0].delayOnlyForIncludeAccount = false

        let start = Date()
        fixture.model.refresh(includeAccount: true)
        while fixture.model.isRefreshing, Date().timeIntervalSince(start) < 2 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertFalse(fixture.model.isRefreshing)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.4)
    }

    func testLocalRefreshResultDoesNotClobberFreshAccountData() async throws {
        let fixture = makeFixture()
        fixture.adapters[0].handler = { previous, includeAccount in
            var snapshot = previous
            if includeAccount {
                snapshot.status = .connected
                snapshot.account = AccountIdentity(planType: "plus", email: nil)
                snapshot.windows = [RateLimitWindow(id: "codex", usedPercent: 31, windowMinutes: 10080, resetsAt: nil)]
            } else {
                snapshot.localTokenUsage = TokenUsage(input: 90, output: 9)
            }
            return snapshot
        }
        // 本地通道慢于账号通道收尾，后到结果不得覆盖先写入的账号数据。
        fixture.adapters[0].delayNanoseconds = 300_000_000
        fixture.adapters[0].delayOnlyForIncludeAccount = false

        fixture.model.refresh(includeAccount: true)
        try await Task.sleep(nanoseconds: 800_000_000)

        XCTAssertEqual(fixture.model.codex.account?.planType, "plus")
        XCTAssertEqual(fixture.model.codex.windows.map(\.windowMinutes), [10080])
        XCTAssertEqual(fixture.model.codex.localTokenUsage.total, 99)
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

    func testRapidRefreshesRecordHistoryAtMostOncePerMinimumInterval() async {
        let fixture = makeFixture()

        fixture.model.refresh(includeAccount: false)
        await waitForRefresh(fixture.model)
        fixture.model.refresh(includeAccount: false)
        await waitForRefresh(fixture.model)

        XCTAssertEqual(fixture.repository.savedSnapshots.count, 1)
        XCTAssertEqual(fixture.model.history.count, 1)
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

    /// 验证打开面板查询逻辑：首次打开触发账号请求，30 秒内快速开合触发防刷冷却，force 强制绕过冷却
    func testRefreshAccountOnPanelOpenAppliesCooldownAndForce() async {
        let fixture = makeFixture()

        // 1. 首次打开面板：发起账号查询
        fixture.model.refreshAccountOnPanelOpen(force: false)
        await waitForRefresh(fixture.model)
        let codexAccountCount1 = fixture.adapters[0].includeAccountValues.filter { $0 }.count
        XCTAssertEqual(codexAccountCount1, 1)

        // 2. 处于 30 秒冷却时间内快速再次打开面板：不应发起账号网络请求（仅本地刷新）
        fixture.model.refreshAccountOnPanelOpen(force: false)
        await waitForRefresh(fixture.model)
        let codexAccountCount2 = fixture.adapters[0].includeAccountValues.filter { $0 }.count
        XCTAssertEqual(codexAccountCount2, 1, "冷却时间内不应发起新的账号请求")

        // 3. 用户手动点击校准（force: true）：无视冷却，强制发起账号请求
        fixture.model.refreshAccountOnPanelOpen(force: true)
        await waitForRefresh(fixture.model)
        let codexAccountCount3 = fixture.adapters[0].includeAccountValues.filter { $0 }.count
        XCTAssertEqual(codexAccountCount3, 2, "force: true 时应强制发起账号请求")
    }

    /// 验证面板关闭时取消在途请求并将 isRefreshing 重置为 false
    func testCancelAccountRefreshResetsRefreshingState() {
        let fixture = makeFixture()
        fixture.model.refresh(includeAccount: true)
        XCTAssertTrue(fixture.model.isRefreshing)

        fixture.model.cancelAccountRefresh()
        XCTAssertFalse(fixture.model.isRefreshing)
    }
}
