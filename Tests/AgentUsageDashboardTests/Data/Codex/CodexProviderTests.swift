import XCTest
@testable import AgentUsageDashboardKit

final class CodexProviderTests: XCTestCase {
    private func makeFixtureRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-provider-fixture-\(UUID().uuidString)", isDirectory: true)
        let sessions = root.appendingPathComponent(".codex/sessions/2026/01/01", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let content = """
        {"type":"event_msg","payload":{"type":"turn_context","model":"gpt-5.1-codex"}}
        {"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"cached_input_tokens":3,"output_tokens":5,"reasoning_output_tokens":2}},"rate_limits":{"primary":{"used_percent":25,"window_minutes":300,"resets_at":1893456000}}}}
        """
        try content.write(
            to: sessions.appendingPathComponent("rollout.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        return root
    }

    func testLocalRefreshUsesSessionLogsWithoutAccountQuery() async throws {
        let root = try makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = CodexProvider(
            collector: CodexSessionCollector(homeURL: root),
            appServerClient: CodexAppServerClient(executableURL: nil)
        )

        let snapshot = await provider.refresh(previous: .empty(.codex), includeAccount: false)

        XCTAssertEqual(snapshot.status, .connected)
        XCTAssertEqual(snapshot.localTokenUsage.total, 20)
        // 额度窗口归账号通道（官方接口）所有，本地日志只负责 token 统计。
        XCTAssertTrue(snapshot.windows.isEmpty)
        XCTAssertEqual(snapshot.source, "session-jsonl")
        XCTAssertNil(snapshot.account)
        XCTAssertNil(snapshot.errorMessage)
    }

    func testAccountRefreshUsesOnlyAppServerWithoutParsingLocalLogs() async throws {
        let root = try makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let executable = root.appendingPathComponent("fake-codex")
        try fakeCodexAppServerScript().write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let provider = CodexProvider(
            collector: CodexSessionCollector(homeURL: root),
            appServerClient: CodexAppServerClient(executableURL: executable)
        )

        let snapshot = await provider.refresh(previous: .empty(.codex), includeAccount: true)

        XCTAssertEqual(snapshot.status, .connected)
        XCTAssertEqual(snapshot.account?.planType, "plus")
        XCTAssertEqual(snapshot.windows.map(\.windowMinutes), [10080])
        XCTAssertEqual(snapshot.accountUsage?.lifetimeTokens, 42)
        // 账号查询走官方接口，不解析本地日志：本机统计字段保持上一份的值。
        XCTAssertEqual(snapshot.localTokenUsage, .zero)
        XCTAssertTrue(snapshot.localModels.isEmpty)
        XCTAssertEqual(snapshot.source, "app-server + session-jsonl")
        XCTAssertNil(snapshot.errorMessage)
    }

    func testAccountFailureKeepsPreviousAccountDataAndReportsError() async throws {
        let root = try makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let previous = ProviderSnapshot(
            provider: .codex,
            status: .connected,
            account: AccountIdentity(planType: "pro", email: nil),
            windows: [RateLimitWindow(id: "codex", usedPercent: 60, windowMinutes: 10080, resetsAt: nil)],
            accountUsage: AccountTokenUsage(lifetimeTokens: 100, peakDailyTokens: nil, dailyBuckets: nil),
            localTokenUsage: .zero,
            localModels: [],
            source: "app-server + session-jsonl",
            collectedAt: .distantPast,
            errorMessage: nil
        )
        let provider = CodexProvider(
            collector: CodexSessionCollector(homeURL: root),
            appServerClient: CodexAppServerClient(executableURL: nil)
        )

        let snapshot = await provider.refresh(previous: previous, includeAccount: true)

        XCTAssertEqual(snapshot.status, .connected)
        XCTAssertEqual(snapshot.account?.planType, "pro")
        // 账号失败时保留上一份账号数据并显示错误，不解析本地日志制造额度窗口。
        XCTAssertEqual(snapshot.windows.map(\.usedPercent), [60])
        XCTAssertEqual(snapshot.accountUsage?.lifetimeTokens, 100)
        XCTAssertEqual(snapshot.localTokenUsage, .zero)
        XCTAssertEqual(snapshot.source, "app-server + session-jsonl")
        XCTAssertNotNil(snapshot.errorMessage)
    }
}
