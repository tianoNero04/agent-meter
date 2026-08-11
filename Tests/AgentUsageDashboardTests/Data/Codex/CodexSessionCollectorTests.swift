import XCTest
@testable import AgentUsageDashboardKit

final class CodexSessionCollectorTests: XCTestCase {
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

        let result = CodexSessionCollector(homeURL: root).collect()

        XCTAssertEqual(result.tokenUsage.input, 10)
        XCTAssertEqual(result.tokenUsage.cachedInput, 3)
        XCTAssertEqual(result.tokenUsage.output, 5)
        XCTAssertEqual(result.tokenUsage.reasoning, 2)
        XCTAssertEqual(result.models.first?.model, "gpt-5.1-codex")
        XCTAssertEqual(result.windows.first?.usedPercent, 25)
        XCTAssertEqual(result.windows.first?.windowMinutes, 300)
    }

    func testCodexCollectorUsesTheMostRecentRateLimitEventAcrossSessions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-latest-rate-limit-\(UUID().uuidString)", isDirectory: true)
        let sessions = root.appendingPathComponent(".codex/sessions", isDirectory: true)
        let newerDirectory = sessions.appendingPathComponent("a-newer", isDirectory: true)
        let olderDirectory = sessions.appendingPathComponent("z-older", isDirectory: true)
        try FileManager.default.createDirectory(at: newerDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: olderDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let newer = #"{"timestamp":"2026-08-03T08:20:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":31,"window_minutes":10080}}}}"#
        let older = #"{"timestamp":"2026-08-03T08:10:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":45,"window_minutes":300},"secondary":{"used_percent":46,"window_minutes":10080}}}}"#
        try newer.write(to: newerDirectory.appendingPathComponent("rollout.jsonl"), atomically: true, encoding: .utf8)
        try older.write(to: olderDirectory.appendingPathComponent("rollout.jsonl"), atomically: true, encoding: .utf8)

        let result = CodexSessionCollector(homeURL: root).collect()

        XCTAssertEqual(result.windows.count, 1)
        XCTAssertEqual(result.windows.first?.usedPercent, 31)
        XCTAssertEqual(result.windows.first?.windowMinutes, 10080)
    }

    func testCodexCollectorOnlyReparsesChangedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-incremental-\(UUID().uuidString)", isDirectory: true)
        let sessions = root.appendingPathComponent(".codex/sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = sessions.appendingPathComponent("a.jsonl")
        let second = sessions.appendingPathComponent("b.jsonl")
        let usageLine = #"{"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"output_tokens":5}}}}"#
        try "\(usageLine)\n".write(to: first, atomically: true, encoding: .utf8)
        try "\(usageLine)\n".write(to: second, atomically: true, encoding: .utf8)

        let collector = CodexSessionCollector(homeURL: root)
        let initial = collector.collect()
        XCTAssertEqual(collector.parsedFileCount, 2)
        XCTAssertEqual(initial.tokenUsage.total, 30)

        // 未变化时复用缓存，不重复解析。
        let unchanged = collector.collect()
        XCTAssertEqual(collector.parsedFileCount, 2)
        XCTAssertEqual(unchanged.tokenUsage.total, 30)

        // 只有内容变化的文件被重新解析（大小变化保证缓存键失效）。
        try "\(usageLine)\n\(usageLine)\n".write(to: second, atomically: true, encoding: .utf8)
        let updated = collector.collect()
        XCTAssertEqual(collector.parsedFileCount, 3)
        XCTAssertEqual(updated.tokenUsage.total, 45)
    }
}
