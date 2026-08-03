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

        let result = CodexLogCollector(homeURL: root).collect()

        XCTAssertEqual(result.windows.count, 1)
        XCTAssertEqual(result.windows.first?.usedPercent, 31)
        XCTAssertEqual(result.windows.first?.windowMinutes, 10080)
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

    func testCodexAppServerParsesAllAvailableRateLimitWindows() {
        let result: [String: Any] = [
            "rateLimitsByLimitId": [
                "codex": [
                    "primary": [
                        "usedPercent": 31,
                        "windowDurationMins": 10080,
                        "resetsAt": 1_896_000_000
                    ],
                    "secondary": [
                        "usedPercent": 12,
                        "windowDurationMins": 300,
                        "resetsAt": 1_895_000_000
                    ]
                ]
            ]
        ]

        let windows = CodexAppServerClient.parseRateLimits(result)

        XCTAssertEqual(windows.map(\.id), ["codex.primary", "codex.secondary"])
        XCTAssertEqual(windows.first?.windowMinutes, 10080)
        XCTAssertEqual(windows.first?.remainingPercent, 69)
    }

    func testRateLimitLabelInterpolatesUnknownWindowDuration() {
        let window = RateLimitWindow(id: "codex", usedPercent: 10, windowMinutes: 1440, resetsAt: nil)

        XCTAssertEqual(window.label, "1440 分钟")
    }

    func testCodexAppServerCompletesHandshakeBeforeReadingAccountData() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-app-server-fixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let executable = root.appendingPathComponent("fake-codex")
        let script = """
#!/usr/bin/env python3
import json
import select
import sys

def read_request():
    line = sys.stdin.readline()
    if not line:
        sys.exit(1)
    return json.loads(line)

read_request()
print(json.dumps({"id": 0, "result": {}}), flush=True)

initialized = read_request()
if initialized.get("method") != "initialized":
    sys.exit(1)

account = read_request()
if account.get("id") != 1:
    sys.exit(1)
print(json.dumps({"id": 1, "result": {"account": {"planType": "plus"}}}), flush=True)

rate_limits = read_request()
if rate_limits.get("id") != 2:
    sys.exit(1)
if select.select([sys.stdin], [], [], 0)[0]:
    sys.exit(0)
print(json.dumps({"id": 2, "result": {"rateLimitsByLimitId": {"codex": {"primary": {"usedPercent": 31, "windowDurationMins": 10080}}}}}), flush=True)

usage = read_request()
if usage.get("id") != 3:
    sys.exit(1)
print(json.dumps({"id": 3, "result": {"summary": {"lifetimeTokens": 42}}}), flush=True)
"""
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let data = try await CodexAppServerClient(executableURL: executable).fetch()

        XCTAssertEqual(data.windows.first?.windowMinutes, 10080)
        XCTAssertEqual(data.windows.first?.remainingPercent, 69)
        XCTAssertEqual(data.usage?.lifetimeTokens, 42)
    }
}
