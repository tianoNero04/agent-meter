import XCTest
@testable import AgentUsageDashboard

final class CollectorTests: XCTestCase {
    func testCodexCollectorAggregatesLastTokenUsageAndRateLimits() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-fixture-\(UUID().uuidString)", isDirectory: true)
        let sessions = root.appendingPathComponent(".codex/sessions/2026/01/01", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = sessions.appendingPathComponent("rollout.jsonl")
        let content = """
        {"type":"event_msg","payload":{"type":"turn_context","model":"gpt-5.1-codex"}}
        {"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"cached_input_tokens":3,"output_tokens":5,"reasoning_output_tokens":2}},"rate_limits":{"primary":{"used_percent":25,"window_minutes":300,"resets_at":1893456000}}}}
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let result = CodexLogCollector(homeURL: root).collect()

        XCTAssertEqual(result.tokenUsage.input, 10)
        XCTAssertEqual(result.tokenUsage.cachedInput, 3)
        XCTAssertEqual(result.tokenUsage.output, 5)
        XCTAssertEqual(result.tokenUsage.reasoning, 2)
        XCTAssertEqual(result.models.first?.model, "gpt-5.1-codex")
        XCTAssertEqual(result.windows.first?.usedPercent, 25)
        XCTAssertEqual(result.windows.first?.windowMinutes, 300)
    }

    func testKimiCollectorMapsWireUsageFields() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kimi-fixture-\(UUID().uuidString)", isDirectory: true)
        let sessions = root.appendingPathComponent(".kimi-code/sessions/example/agents/main", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = sessions.appendingPathComponent("wire.jsonl")
        let content = """
        {"modelAlias":"k3","usage":{"inputCacheCreation":2,"inputCacheRead":4,"inputOther":8,"output":6}}
        """
        try content.write(to: file, atomically: true, encoding: .utf8)

        let result = KimiLogCollector(homeURL: root).collect()

        XCTAssertEqual(result.tokenUsage.input, 10)
        XCTAssertEqual(result.tokenUsage.cachedInput, 4)
        XCTAssertEqual(result.tokenUsage.output, 6)
        XCTAssertEqual(result.models.first?.model, "k3")
    }
}
