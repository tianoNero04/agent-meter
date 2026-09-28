import XCTest
import SQLite3
@testable import AgentUsageDashboardKit

final class AntigravityProviderTests: XCTestCase {
    private var tempDir: URL!
    private var dbURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AntigravityProviderTests-\(UUID().uuidString)")
        let toolsDir = tempDir.appendingPathComponent(".antigravity_tools")
        try FileManager.default.createDirectory(at: toolsDir, withIntermediateDirectories: true)
        dbURL = toolsDir.appendingPathComponent("token_stats.db")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    /// 验证本地通道刷新时，仅更新 token 统计，额度窗口保持 previous 不变
    func testLocalRefreshUpdatesSessionStatsWithoutChangingWindows() async throws {
        // 创建测试数据库并插入一条记录
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let sql = """
        CREATE TABLE token_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            account_email TEXT NOT NULL,
            model TEXT NOT NULL,
            input_tokens INTEGER NOT NULL,
            output_tokens INTEGER NOT NULL,
            cached_tokens INTEGER NOT NULL,
            total_tokens INTEGER NOT NULL
        );
        INSERT INTO token_usage VALUES (1, \(Int(Date().timeIntervalSince1970)), 'test@google.com', 'gemini-3.6-flash-high', 100, 20, 50, 170);
        """
        XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK)

        let collector = AntigravitySessionCollector(homeURL: tempDir)
        let directClient = AntigravityDirectApiClient(homeURL: tempDir, allowKeychain: false)
        let provider = AntigravityProvider(collector: collector, directApiClient: directClient)

        let previous = ProviderSnapshot(
            provider: .antigravity,
            status: .connected,
            account: AccountIdentity(planType: "PRO", email: "test@google.com"),
            windows: [RateLimitWindow(id: "antigravity.5h", usedPercent: 12.0, windowMinutes: 300)],
            accountUsage: nil,
            localTokenUsage: .zero,
            localDailyBuckets: [],
            localModels: [],
            source: "direct-api + token-stats",
            collectedAt: .distantPast,
            errorMessage: nil
        )

        let snapshot = await provider.refresh(previous: previous, includeAccount: false)

        XCTAssertEqual(snapshot.status, .connected)
        XCTAssertEqual(snapshot.localTokenUsage.input, 100)
        XCTAssertEqual(snapshot.localTokenUsage.output, 20)
        XCTAssertEqual(snapshot.localTokenUsage.cachedInput, 50)
        XCTAssertEqual(snapshot.localModels.count, 1)
        XCTAssertEqual(snapshot.localModels.first?.model, "gemini-3.6-flash-high")
        // 额度窗口应保持 previous 的窗口
        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertEqual(snapshot.windows.first?.id, "antigravity.5h")
    }

    /// 验证账号通道刷新失败时，保留上一份快照的数据并填充错误信息
    func testAccountRefreshFailureRetainsPreviousDataAndSetsError() async {
        let collector = AntigravitySessionCollector(homeURL: tempDir)
        let directClient = AntigravityDirectApiClient(homeURL: tempDir, allowKeychain: false)
        let provider = AntigravityProvider(collector: collector, directApiClient: directClient)

        let previous = ProviderSnapshot(
            provider: .antigravity,
            status: .connected,
            account: AccountIdentity(planType: "FREE", email: "saved_user@gmail.com"),
            windows: [RateLimitWindow(id: "antigravity.5h", usedPercent: 10.0, windowMinutes: 300)],
            accountUsage: nil,
            localTokenUsage: TokenUsage(input: 50, cachedInput: 0, output: 10, reasoning: 0),
            localDailyBuckets: [],
            localModels: [],
            source: "token-stats",
            collectedAt: .distantPast,
            errorMessage: nil
        )

        let snapshot = await provider.refresh(previous: previous, includeAccount: true)

        XCTAssertEqual(snapshot.status, .connected)
        XCTAssertEqual(snapshot.account?.email, "saved_user@gmail.com")
        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertEqual(snapshot.windows.first?.id, "antigravity.5h")
        XCTAssertNotNil(snapshot.errorMessage)
    }

    /// 验证 BundleImages 正确装载 Antigravity 官方 App 图标位图
    func testBundleImagesLoadsAntigravityIcon() {
        let icon = BundleImages.providerIcon(for: .antigravity)
        XCTAssertNotNil(icon)
    }
}
