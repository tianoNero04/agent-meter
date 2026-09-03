import XCTest
@testable import AgentUsageDashboardKit

@MainActor
final class RefreshCoordinatorTests: XCTestCase {
    private func makeAdapters() -> [FakeUsageProviderAdapter] {
        [
            FakeUsageProviderAdapter(provider: .codex),
            FakeUsageProviderAdapter(provider: .kimiCode)
        ]
    }

    func testRefreshRoutesIncludeAccountToEveryAdapter() async {
        let adapters = makeAdapters()
        let coordinator = RefreshCoordinator(adapters: adapters)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            coordinator.refresh(previous: [:], includeAccount: true) { snapshots in
                XCTAssertEqual(snapshots.count, 2)
                continuation.resume()
            }
        }

        XCTAssertEqual(adapters.map(\.includeAccountValues), [[true], [true]])

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            coordinator.refresh(previous: [:], includeAccount: false) { _ in
                continuation.resume()
            }
        }

        XCTAssertEqual(adapters.map(\.includeAccountValues), [[true, false], [true, false]])
    }

    func testScheduleLocalRefreshDebouncesIntoASingleLocalRefresh() async throws {
        let adapters = makeAdapters()
        let coordinator = RefreshCoordinator(adapters: adapters, debounceNanoseconds: 50_000_000)

        var finishCount = 0
        coordinator.scheduleLocalRefresh(previous: { [:] }) { _ in finishCount += 1 }
        coordinator.scheduleLocalRefresh(previous: { [:] }) { _ in finishCount += 1 }

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(finishCount, 1)
        XCTAssertEqual(adapters.map(\.includeAccountValues), [[false], [false]])
    }

    func testRefreshTimesOutAndFallsBackToPreviousSnapshot() async throws {
        let slow = FakeUsageProviderAdapter(provider: .codex)
        slow.delayNanoseconds = 10_000_000_000
        let coordinator = RefreshCoordinator(adapters: [slow], timeoutNanoseconds: 50_000_000)

        let prior = ProviderSnapshot.empty(.codex)
        let snapshots = await withCheckedContinuation { continuation in
            coordinator.refresh(previous: [.codex: prior], includeAccount: true) { snapshots in
                continuation.resume(returning: snapshots)
            }
        }

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.errorMessage, "刷新超时，保留上次数据")
        XCTAssertEqual(snapshots.first?.collectedAt, prior.collectedAt)
    }

    func testRefreshCoalescesWithTheInFlightRefresh() async throws {
        let slow = FakeUsageProviderAdapter(provider: .codex)
        slow.delayNanoseconds = 300_000_000
        let coordinator = RefreshCoordinator(adapters: [slow])

        var finishCount = 0
        coordinator.refresh(previous: [:], includeAccount: false) { _ in finishCount += 1 }
        try await Task.sleep(nanoseconds: 50_000_000)
        coordinator.refresh(previous: [:], includeAccount: false) { _ in finishCount += 1 }

        try await Task.sleep(nanoseconds: 900_000_000)

        // 并发刷新不再取消旧任务，而是合并为一次挂起刷新，两次都正常收尾。
        XCTAssertEqual(finishCount, 2)
        XCTAssertEqual(slow.refreshCount, 2)
    }

    func testAccountLaneIsNotBlockedBySlowLocalLane() async throws {
        let adapter = FakeUsageProviderAdapter(provider: .codex)
        adapter.delayNanoseconds = 400_000_000
        adapter.delayOnlyForIncludeAccount = false
        let coordinator = RefreshCoordinator(adapters: [adapter])

        var accountFinished = false
        var localFinished = false
        coordinator.refresh(previous: [:], includeAccount: false) { _ in localFinished = true }
        try await Task.sleep(nanoseconds: 50_000_000)
        coordinator.refresh(previous: [:], includeAccount: true) { _ in accountFinished = true }

        // 本地通道还在跑（400ms），账号通道应已独立收尾。
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertTrue(accountFinished)
        XCTAssertFalse(localFinished)

        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertTrue(localFinished)
        XCTAssertEqual(adapter.includeAccountValues, [false, true])
    }

    func testCoalescingIsIndependentPerLane() async throws {
        let adapter = FakeUsageProviderAdapter(provider: .codex)
        adapter.delayNanoseconds = 300_000_000
        let coordinator = RefreshCoordinator(adapters: [adapter])

        var accountFinishes = 0
        var localFinishes = 0
        coordinator.refresh(previous: [:], includeAccount: true) { _ in accountFinishes += 1 }
        coordinator.refresh(previous: [:], includeAccount: false) { _ in localFinishes += 1 }
        try await Task.sleep(nanoseconds: 50_000_000)
        coordinator.refresh(previous: [:], includeAccount: true) { _ in accountFinishes += 1 }
        coordinator.refresh(previous: [:], includeAccount: false) { _ in localFinishes += 1 }

        try await Task.sleep(nanoseconds: 1_200_000_000)

        // 两条通道各自合并排队、各自收尾，互不占用对方队列。
        XCTAssertEqual(accountFinishes, 2)
        XCTAssertEqual(localFinishes, 2)
        XCTAssertEqual(adapter.refreshCount, 4)
    }
}
