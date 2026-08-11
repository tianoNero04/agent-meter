import Foundation

struct CodexLocalData {
    var tokenUsage: TokenUsage
    var models: [ModelUsage]
    var windows: [RateLimitWindow]
    var latestModel: String?
}

/// Codex 本机会话采集器。
/// 按文件缓存解析结果（修改时间 + 文件大小为键），只有变化的文件才重新解析，
/// 避免每次刷新都把全部会话日志读入内存。
final class CodexSessionCollector {
    private struct CachedFile {
        var modificationDate: Date?
        var fileSize: Int?
        var usage: TokenUsage = .zero
        var modelTotals: [String: TokenUsage] = [:]
        var latestModel: String?
        var latestRateLimitDate: Date?
        var latestWindows: [RateLimitWindow] = []
    }

    private let sessionsURL: URL
    private let lock = NSLock()
    private var cache: [String: CachedFile] = [:]

    /// 实际执行过完整解析的文件数，供测试验证增量行为。
    private(set) var parsedFileCount = 0

    init(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        sessionsURL = homeURL.appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    func collect() -> CodexLocalData {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return CodexLocalData(tokenUsage: .zero, models: [], windows: [], latestModel: nil)
        }

        var total = TokenUsage.zero
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

    private func parseFile(_ fileURL: URL, fileDate: Date?) -> CachedFile {
        var result = CachedFile()
        var currentModel: String?
        let fractionalTimestampFormatter = ISO8601DateFormatter()
        fractionalTimestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime]

        for line in FileLineSequence(url: fileURL) {
            // 逐行释放 JSONSerialization 产生的 autorelease 对象，
            // 避免大文件解析时对象堆积到整个任务结束才释放。
            autoreleasepool {
                guard let object = JSONSupport.jsonObject(from: line) else { return }
                let payload = object["payload"] as? [String: Any] ?? object
                let eventType = JSONSupport.string(payload["type"])

                if eventType == "turn_context" {
                    currentModel = JSONSupport.string(payload["model"])
                        ?? JSONSupport.string(payload["model_provider"])
                }

                if eventType == "token_count" {
                    if let delta = JSONSupport.object(payload, path: ["info", "last_token_usage"]),
                       let usage = JSONSupport.tokenUsage(delta) {
                        result.usage = result.usage + usage
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
