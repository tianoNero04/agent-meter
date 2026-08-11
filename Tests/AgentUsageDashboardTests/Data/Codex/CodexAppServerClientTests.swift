import XCTest
@testable import AgentUsageDashboardKit

final class CodexAppServerClientTests: XCTestCase {
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

    func testCodexAppServerParsesWeeklyOnlyRateLimitWindow() {
        let result: [String: Any] = [
            "rateLimitsByLimitId": [
                "codex": [
                    "primary": [
                        "usedPercent": 55,
                        "windowDurationMins": 10080
                    ]
                ]
            ]
        ]

        let windows = CodexAppServerClient.parseRateLimits(result)

        XCTAssertEqual(windows.map(\.id), ["codex"])
        XCTAssertEqual(windows.first?.windowMinutes, 10080)
        XCTAssertEqual(windows.first?.label, "本周")
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
