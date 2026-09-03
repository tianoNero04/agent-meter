import XCTest
@testable import AgentUsageDashboardKit

final class KimiProviderTests: XCTestCase {
    func testLocalRefreshReturnsSessionStatsWithoutAccountData() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kimi-provider-fixture-\(UUID().uuidString)", isDirectory: true)
        let sessions = root.appendingPathComponent(".kimi-code/sessions/example/agents/main", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let content = """
        {"timestamp":"2026-08-04T09:00:00Z","modelAlias":"k3","usage":{"inputOther":10,"output":5}}
        """
        try content.write(
            to: sessions.appendingPathComponent("wire.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let provider = KimiProvider(collector: KimiSessionCollector(homeURL: root))
        let snapshot = await provider.refresh(previous: .empty(.kimiCode), includeAccount: false)

        XCTAssertEqual(snapshot.status, .connected)
        XCTAssertEqual(snapshot.localTokenUsage.total, 15)
        XCTAssertEqual(snapshot.localDailyBuckets.count, 1)
        XCTAssertEqual(snapshot.localModels.first?.model, "k3")
        XCTAssertEqual(snapshot.source, "wire-jsonl")
        XCTAssertNil(snapshot.account)
        XCTAssertTrue(snapshot.windows.isEmpty)
        XCTAssertNil(snapshot.errorMessage)
    }

    /// 验证账号刷新失败（如凭据缺失）时保留上一份可用数据并透传错误信息
    func testAccountRefreshFailureRetainsPreviousAccountDataAndReportsError() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kimi-provider-noop-\(UUID().uuidString)", isDirectory: true)
        let sessions = root.appendingPathComponent(".kimi-code/sessions/example/agents/main", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = KimiProvider(collector: KimiSessionCollector(homeURL: root))
        let previous = ProviderSnapshot(
            provider: .kimiCode,
            status: .connected,
            account: AccountIdentity(planType: "INTERMEDIATE", email: "kimi-user"),
            windows: [RateLimitWindow(id: "kimi.primary", usedPercent: 10, windowMinutes: 300, resetsAt: nil)],
            accountUsage: nil,
            localTokenUsage: .zero,
            localDailyBuckets: [],
            localModels: [],
            source: "direct-api + wire-jsonl",
            collectedAt: .distantPast,
            errorMessage: nil
        )
        let snapshot = await provider.refresh(previous: previous, includeAccount: true)

        XCTAssertEqual(snapshot.status, .connected)
        XCTAssertEqual(snapshot.account?.planType, "INTERMEDIATE")
        XCTAssertEqual(snapshot.windows.map(\.usedPercent), [10])
        XCTAssertNotNil(snapshot.errorMessage)
    }

    func testLocalRefreshWithoutLogsReportsUnavailable() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kimi-provider-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = KimiProvider(collector: KimiSessionCollector(homeURL: root))
        let snapshot = await provider.refresh(previous: .empty(.kimiCode), includeAccount: false)

        XCTAssertEqual(snapshot.status, .unavailable)
        XCTAssertEqual(snapshot.localTokenUsage, .zero)
    }
}
