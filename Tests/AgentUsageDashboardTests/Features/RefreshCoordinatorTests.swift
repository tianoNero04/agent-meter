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

    func testRefreshCancelsThePreviousInFlightRefresh() async throws {
        let slow = FakeUsageProviderAdapter(provider: .codex)
        slow.delayNanoseconds = 300_000_000
        let coordinator = RefreshCoordinator(adapters: [slow])

        var finishCount = 0
        coordinator.refresh(previous: [:], includeAccount: false) { _ in finishCount += 1 }
        try await Task.sleep(nanoseconds: 50_000_000)
        coordinator.refresh(previous: [:], includeAccount: false) { _ in finishCount += 1 }

        try await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(finishCount, 1)
        XCTAssertEqual(slow.refreshCount, 2)
    }
}
