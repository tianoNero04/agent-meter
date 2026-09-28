import XCTest
import SQLite3
@testable import AgentUsageDashboardKit

final class AntigravitySessionCollectorTests: XCTestCase {
    private var tempDir: URL!
    private var dbURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AntigravityCollectorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        dbURL = tempDir.appendingPathComponent("token_stats.db")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    /// 验证从 SQLite 数据库正确读取 Token 用量、模型分布与每日分桶
    func testCollectReadsTokensAndBucketsFromSQLite() throws {
        // 创建测试数据库并插入样本数据
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let createTableSQL = """
        CREATE TABLE token_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            account_email TEXT NOT NULL,
            model TEXT NOT NULL,
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0,
            cached_tokens INTEGER NOT NULL DEFAULT 0,
            total_tokens INTEGER NOT NULL DEFAULT 0
        );
        """
        XCTAssertEqual(sqlite3_exec(db, createTableSQL, nil, nil, nil), SQLITE_OK)

        let now = Date().timeIntervalSince1970
        let insertSQL = """
        INSERT INTO token_usage (timestamp, account_email, model, input_tokens, output_tokens, cached_tokens, total_tokens) VALUES
        (\(Int(now)), 'user@example.com', 'claude-sonnet-4-6', 1000, 200, 500, 1700),
        (\(Int(now)), 'user@example.com', 'gemini-3.6-flash-high', 2000, 400, 1000, 3400);
        """
        XCTAssertEqual(sqlite3_exec(db, insertSQL, nil, nil, nil), SQLITE_OK)

        let collector = AntigravitySessionCollector(customDatabaseURL: dbURL)
        let result = collector.collect()

        // 校验总用量
        XCTAssertEqual(result.tokenUsage.input, 3000)
        XCTAssertEqual(result.tokenUsage.output, 600)
        XCTAssertEqual(result.tokenUsage.cachedInput, 1500)
        XCTAssertEqual(result.tokenUsage.total, 5100)

        // 校验模型排行（总用量降序：gemini 3400 > claude 1700）
        XCTAssertEqual(result.models.count, 2)
        XCTAssertEqual(result.models[0].model, "gemini-3.6-flash-high")
        XCTAssertEqual(result.models[0].usage.total, 3400)
        XCTAssertEqual(result.models[1].model, "claude-sonnet-4-6")
        XCTAssertEqual(result.models[1].usage.total, 1700)

        // 校验每日分桶存在
        XCTAssertFalse(result.dailyBuckets.isEmpty)
    }

    /// 验证数据库文件不存在时安全返回空结构
    func testCollectReturnsEmptyWhenDatabaseMissing() {
        let missingURL = tempDir.appendingPathComponent("non_existent.db")
        let collector = AntigravitySessionCollector(customDatabaseURL: missingURL)
        let result = collector.collect()
        XCTAssertEqual(result, .empty)
    }

    /// 验证在 WAL 模式下正确读取数据
    func testCollectReadsWALModeDatabase() {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        // 设置为 WAL 模式
        XCTAssertEqual(sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil), SQLITE_OK)

        let createSQL = """
        CREATE TABLE IF NOT EXISTS token_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            account_email TEXT NOT NULL,
            model TEXT NOT NULL,
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0,
            cached_tokens INTEGER NOT NULL DEFAULT 0,
            total_tokens INTEGER NOT NULL DEFAULT 0
        );
        INSERT INTO token_usage VALUES (1, \(Int(Date().timeIntervalSince1970)), 'wal@google.com', 'gemini-3-flash', 10, 5, 2, 17);
        """
        XCTAssertEqual(sqlite3_exec(db, createSQL, nil, nil, nil), SQLITE_OK)

        let collector = AntigravitySessionCollector(customDatabaseURL: dbURL)
        let result = collector.collect()

        XCTAssertEqual(result.tokenUsage.total, 17)
        XCTAssertEqual(result.models.first?.model, "gemini-3-flash")
    }
}
