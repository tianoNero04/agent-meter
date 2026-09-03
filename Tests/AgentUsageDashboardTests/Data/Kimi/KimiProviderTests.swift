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

    func testAccountRefreshIsNoOpWithoutAccountAPI() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kimi-provider-noop-\(UUID().uuidString)", isDirectory: true)
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
        // 账号接口尚未接入：账号通道不解析本地日志，原样返回上一份快照。
        let previous = ProviderSnapshot.empty(.kimiCode)
        let snapshot = await provider.refresh(previous: previous, includeAccount: true)

        XCTAssertEqual(snapshot, previous)
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
