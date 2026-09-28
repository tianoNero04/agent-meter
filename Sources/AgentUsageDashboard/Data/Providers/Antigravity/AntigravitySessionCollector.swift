import Foundation
import SQLite3

/// Antigravity 本地采集汇总数据
struct AntigravityCollectedUsage: Equatable {
    var tokenUsage: TokenUsage
    var dailyBuckets: [DailyTokenBucket]
    var models: [ModelUsage]

    static let empty = AntigravityCollectedUsage(
        tokenUsage: .zero,
        dailyBuckets: [],
        models: []
    )
}

/// Antigravity 本地 Token 用量采集器：
/// 从 ~/.antigravity_tools/token_stats.db 只读读取由 Antigravity 代理记录的 Token 账本，
/// 统计总 Token（输入、输出、缓存）、各模型消耗排行及最近 30 天每日趋势分桶。
struct AntigravitySessionCollector {
    var homeURL: URL = FileManager.default.homeDirectoryForCurrentUser
    var customDatabaseURL: URL?

    /// 目标数据库文件路径
    var databaseURL: URL {
        customDatabaseURL ?? homeURL.appendingPathComponent(".antigravity_tools/token_stats.db")
    }

    /// 执行本地 Token 统计采集
    func collect() -> AntigravityCollectedUsage {
        let dbPath = databaseURL.path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            return .empty
        }

        var db: OpaquePointer?
        // 打开 SQLite 数据库（使用 READWRITE 兼容 WAL 模式与 shm 共享内存索引读取）
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let db = db else {
            if let db = db { sqlite3_close(db) }
            return .empty
        }
        defer { sqlite3_close(db) }

        // 1. 查询各模型 Token 消耗分布
        let models = queryModelUsage(db: db)

        // 2. 查询最近 30 天每日时间线用于生成趋势分桶
        let dailyBuckets = queryDailyBuckets(db: db)

        // 3. 汇总全局总用量
        let totalUsage = models.reduce(TokenUsage.zero) { $0 + $1.usage }

        return AntigravityCollectedUsage(
            tokenUsage: totalUsage,
            dailyBuckets: dailyBuckets,
            models: models
        )
    }

    /// 按模型统计 Token 用量并按总消耗降序排列
    private func queryModelUsage(db: OpaquePointer) -> [ModelUsage] {
        let sql = """
            SELECT model,
                   SUM(input_tokens),
                   SUM(output_tokens),
                   SUM(cached_tokens)
            FROM token_usage
            GROUP BY model
            ORDER BY (SUM(input_tokens) + SUM(output_tokens) + SUM(cached_tokens)) DESC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var results: [ModelUsage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let modelCString = sqlite3_column_text(stmt, 0) else { continue }
            let modelName = String(cString: modelCString)
            let inputTokens = Int(sqlite3_column_int64(stmt, 1))
            let outputTokens = Int(sqlite3_column_int64(stmt, 2))
            let cachedTokens = Int(sqlite3_column_int64(stmt, 3))

            let usage = TokenUsage(
                input: max(0, inputTokens),
                cachedInput: max(0, cachedTokens),
                output: max(0, outputTokens),
                reasoning: 0
            )

            results.append(ModelUsage(model: modelName, usage: usage))
        }

        return results
    }

    /// 查询过去 30 天事件并按天聚合生成 DailyTokenBucket
    private func queryDailyBuckets(db: OpaquePointer) -> [DailyTokenBucket] {
        // 限制查询范围为最近 30 天
        let cutoffTimestamp = Int(Date().addingTimeInterval(-30 * 24 * 60 * 60).timeIntervalSince1970)
        let sql = """
            SELECT timestamp,
                   input_tokens,
                   output_tokens,
                   cached_tokens
            FROM token_usage
            WHERE timestamp >= ?
            ORDER BY timestamp ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, sqlite3_int64(cutoffTimestamp))

        var events: [(date: Date, usage: TokenUsage)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let timestamp = sqlite3_column_int64(stmt, 0)
            let inputTokens = Int(sqlite3_column_int64(stmt, 1))
            let outputTokens = Int(sqlite3_column_int64(stmt, 2))
            let cachedTokens = Int(sqlite3_column_int64(stmt, 3))

            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let usage = TokenUsage(
                input: max(0, inputTokens),
                cachedInput: max(0, cachedTokens),
                output: max(0, outputTokens),
                reasoning: 0
            )

            events.append((date: date, usage: usage))
        }

        return DailyTokenAggregation.buckets(from: events)
    }
}
