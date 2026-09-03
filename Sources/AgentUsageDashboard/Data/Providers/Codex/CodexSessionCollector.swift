import Foundation

/// Codex 本地日志提取数据结构（包含总量、每日分桶、模型用量与最新额度窗口）
struct CodexLocalData {
    var tokenUsage: TokenUsage
    var dailyBuckets: [DailyTokenBucket]
    var models: [ModelUsage]
    var windows: [RateLimitWindow]
    var latestModel: String?
}

/// Codex 本机会话采集器（对齐 cc-switch 的 session_usage_codex.rs 提取算法）：
/// 1. 按文件缓存解析结果（修改时间 + 文件大小为键），仅变动文件重新解析；
/// 2. 支持 last_token_usage 与 total_token_usage 增量计算，准确统计 input / cached / output / reasoning；
/// 3. 按时间戳聚合每日 Token 消耗生成 7 日历史分桶。
final class CodexSessionCollector {
    private struct CachedFile {
        var modificationDate: Date?
        var fileSize: Int?
        var usage: TokenUsage = .zero
        var dailyEvents: [(date: Date, usage: TokenUsage)] = []
        var modelTotals: [String: TokenUsage] = [:]
        var latestModel: String?
        var latestRateLimitDate: Date?
        var latestWindows: [RateLimitWindow] = []
    }

    /// 会话根目录对应的 Home 目录
    let homeURL: URL
    private let sessionsURL: URL
    private let lock = NSLock()
    private var cache: [String: CachedFile] = [:]

    /// 实际执行过完整解析的文件数，供测试验证增量行为。
    private(set) var parsedFileCount = 0

    init(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeURL = homeURL
        sessionsURL = homeURL.appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    func collect() -> CodexLocalData {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return CodexLocalData(tokenUsage: .zero, dailyBuckets: [], models: [], windows: [], latestModel: nil)
        }

        var total = TokenUsage.zero
        var dailyEvents: [(date: Date, usage: TokenUsage)] = []
        var modelTotals: [String: TokenUsage] = [:]
        var latestWindows: [RateLimitWindow] = []
        var latestRateLimitDate: Date?
        var latestModel: String?
        var seen: Set<String> = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            seen.insert(fileURL.path)
            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let file = cachedFile(
                for: fileURL,
                modificationDate: values?.contentModificationDate,
                fileSize: values?.fileSize
            )

            total = total + file.usage
            dailyEvents.append(contentsOf: file.dailyEvents)
            for (model, usage) in file.modelTotals {
                modelTotals[model, default: .zero] = modelTotals[model, default: .zero] + usage
            }
            if let model = file.latestModel { latestModel = model }
            if let date = file.latestRateLimitDate,
               latestRateLimitDate == nil || date >= latestRateLimitDate! {
                latestWindows = file.latestWindows
                latestRateLimitDate = date
            }
        }

        pruneCache(keeping: seen)

        let models = modelTotals
            .map { ModelUsage(model: $0.key, usage: $0.value) }
            .sorted { $0.usage.total > $1.usage.total }

        return CodexLocalData(
            tokenUsage: total,
            dailyBuckets: DailyTokenAggregation.buckets(from: dailyEvents),
            models: models,
            windows: latestWindows,
            latestModel: latestModel
        )
    }

    private func cachedFile(for url: URL, modificationDate: Date?, fileSize: Int?) -> CachedFile {
        lock.lock()
        let hit = cache[url.path].flatMap {
            $0.modificationDate == modificationDate && $0.fileSize == fileSize ? $0 : nil
        }
        lock.unlock()
        if let hit { return hit }

        var parsed = parseFile(url, fileDate: modificationDate)
        parsed.modificationDate = modificationDate
        parsed.fileSize = fileSize

        lock.lock()
        cache[url.path] = parsed
        parsedFileCount += 1
        lock.unlock()
        return parsed
    }

    private func pruneCache(keeping seen: Set<String>) {
        lock.lock()
        cache = cache.filter { seen.contains($0.key) }
        lock.unlock()
    }

    private static let tokenCountMarker = Data("\"token_count\"".utf8)
    private static let turnContextMarker = Data("\"turn_context\"".utf8)

    private func parseFile(_ fileURL: URL, fileDate: Date?) -> CachedFile {
        var result = CachedFile()
        var currentModel: String?
        var previousCumulativeUsage: TokenUsage? = nil

        let fractionalTimestampFormatter = ISO8601DateFormatter()
        fractionalTimestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime]

        let iterator = FileLineSequence(url: fileURL).makeIterator()
        while let lineData = iterator.nextData() {
            // 粗筛优化：仅包含 token_count 或 turn_context 标记的行才进行 JSON 解析
            guard lineData.range(of: Self.tokenCountMarker) != nil
                || lineData.range(of: Self.turnContextMarker) != nil else { continue }

            autoreleasepool {
                guard let object = JSONSupport.jsonObject(from: lineData) else { return }
                let payload = object["payload"] as? [String: Any] ?? object
                let eventType = JSONSupport.string(payload["type"])

                if eventType == "turn_context" {
                    currentModel = JSONSupport.string(payload["model"])
                        ?? JSONSupport.string(payload["model_provider"])
                }

                if eventType == "token_count" {
                    // 仿照 cc-switch：优先读取 last_token_usage；若无则从 total_token_usage 计算 delta
                    let lastUsage = JSONSupport.object(payload, path: ["info", "last_token_usage"]).flatMap(JSONSupport.tokenUsage)
                    let totalUsage = JSONSupport.object(payload, path: ["info", "total_token_usage"]).flatMap(JSONSupport.tokenUsage)

                    let delta: TokenUsage? = {
                        if let last = lastUsage {
                            return last
                        } else if let total = totalUsage {
                            let diff = previousCumulativeUsage != nil ? (total - previousCumulativeUsage!) : total
                            return diff
                        }
                        return nil
                    }()

                    if let total = totalUsage {
                        previousCumulativeUsage = total
                    }

                    if let usage = delta, usage.total > 0 {
                        result.usage = result.usage + usage

                        let eventDate = JSONSupport.string(object["timestamp"])
                            .flatMap { fractionalTimestampFormatter.date(from: $0) ?? timestampFormatter.date(from: $0) }
                            ?? fileDate
                            ?? Date()
                        result.dailyEvents.append((date: eventDate, usage: usage))

                        let model = currentModel ?? JSONSupport.string(payload["model"]) ?? "Codex"
                        result.modelTotals[model, default: .zero] = result.modelTotals[model, default: .zero] + usage
                        result.latestModel = model
                    }

                    if let rateLimits = JSONSupport.object(payload, path: ["rate_limits"]) {
                        let timestamp = JSONSupport.string(object["timestamp"])
                            .flatMap { fractionalTimestampFormatter.date(from: $0) ?? timestampFormatter.date(from: $0) }
                            ?? fileDate
                            ?? .distantPast
                        if result.latestRateLimitDate == nil || timestamp >= result.latestRateLimitDate! {
                            result.latestWindows = parseWindows(rateLimits)
                            result.latestRateLimitDate = timestamp
                        }
                    }
                }
            }
        }
        return result
    }

    private func parseWindows(_ object: [String: Any]) -> [RateLimitWindow] {
        object.compactMap { key, value in
            guard let bucket = value as? [String: Any],
                  let used = JSONSupport.double(bucket["used_percent"] ?? bucket["usedPercent"]) else { return nil }
            return RateLimitWindow(
                id: key,
                usedPercent: used,
                windowMinutes: JSONSupport.int(bucket["window_minutes"] ?? bucket["windowDurationMins"]),
                resetsAt: JSONSupport.dateFromUnixSeconds(bucket["resets_at"] ?? bucket["resetsAt"])
            )
        }
        .sorted { $0.id < $1.id }
    }
}
