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
/// 1. 按文件身份缓存汇总结果，完整行后的追加只读取新字节；替换或截断时重建；
/// 2. 支持 last_token_usage 与 total_token_usage 增量计算，准确统计 input / cached / output / reasoning；
/// 3. 按时间戳聚合每日 Token 消耗生成 7 日历史分桶。
final class CodexSessionCollector {
    private struct CachedFile {
        var modificationDate: Date?
        var fileSize: Int?
        var fileIdentifier: NSObject?
        var tailSignature: Data?
        var canAppend = false
        var usage: TokenUsage = .zero
        var dailyTotals: [Date: Int] = [:]
        var modelTotals: [String: TokenUsage] = [:]
        var currentModel: String?
        var previousCumulativeUsage: TokenUsage?
        var latestModel: String?
        var latestRateLimitDate: Date?
        var latestWindows: [RateLimitWindow] = []
    }

    /// 会话根目录对应的 Home 目录
    let homeURL: URL
    private let sessionsURL: URL
    private let lock = NSLock()
    private let collectionLock = NSLock()
    private var cache: [String: CachedFile] = [:]

    /// 实际执行过文件读取/解析的批次数，用于诊断增量行为。
    private(set) var parsedFileCount = 0
    /// 实际读取的日志字节数，用于诊断增量采集成本（不保存日志正文）。
    private(set) var parsedByteCount: UInt64 = 0

    init(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeURL = homeURL
        sessionsURL = homeURL.appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    func collect() -> CodexLocalData {
        collectionLock.lock()
        defer { collectionLock.unlock() }
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return CodexLocalData(tokenUsage: .zero, dailyBuckets: [], models: [], windows: [], latestModel: nil)
        }

        var total = TokenUsage.zero
        var dailyTotals: [Date: Int] = [:]
        var modelTotals: [String: TokenUsage] = [:]
        var latestWindows: [RateLimitWindow] = []
        var latestRateLimitDate: Date?
        var latestModel: String?
        var seen: Set<String> = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            seen.insert(fileURL.path)
            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .fileResourceIdentifierKey])
            let file = cachedFile(
                for: fileURL,
                modificationDate: values?.contentModificationDate,
                fileSize: values?.fileSize,
                fileIdentifier: values?.fileResourceIdentifier as? NSObject
            )

            total = total + file.usage
            for (day, tokens) in file.dailyTotals { dailyTotals[day, default: 0] += tokens }
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
            dailyBuckets: dailyTotals.map { DailyTokenBucket(startDate: $0.key, tokens: $0.value) }
                .sorted { $0.startDate < $1.startDate },
            models: models,
            windows: latestWindows,
            latestModel: latestModel
        )
    }

    private func cachedFile(for url: URL, modificationDate: Date?, fileSize: Int?, fileIdentifier: NSObject?) -> CachedFile {
        lock.lock()
        let prior = cache[url.path]
        lock.unlock()
        let sameFile = fileIdentifier != nil && prior?.fileIdentifier == fileIdentifier
        if let prior, sameFile, prior.modificationDate == modificationDate, prior.fileSize == fileSize { return prior }

        var offset: UInt64 = 0
        if let prior, sameFile, prior.canAppend, let oldSize = prior.fileSize,
           let fileSize, fileSize > oldSize,
           let signature = prior.tailSignature, signature == tailSignature(url, endingAt: oldSize) {
            offset = UInt64(oldSize)
        }

        var parsed = parseFile(url, fileDate: modificationDate, initial: offset > 0 ? prior : nil,
                               startOffset: offset, readLimit: fileSize.map { UInt64($0) - offset })
        parsed.modificationDate = modificationDate
        parsed.fileSize = fileSize
        parsed.fileIdentifier = fileIdentifier
        parsed.tailSignature = fileSize.flatMap { tailSignature(url, endingAt: $0) }

        lock.lock()
        cache[url.path] = parsed
        parsedFileCount += 1
        lock.unlock()
        return parsed
    }

    private func tailSignature(_ url: URL, endingAt size: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            let length = min(size, 64)
            try handle.seek(toOffset: UInt64(size - length))
            return try handle.read(upToCount: length)
        } catch { return nil }
    }

    private func pruneCache(keeping seen: Set<String>) {
        lock.lock()
        cache = cache.filter { seen.contains($0.key) }
        lock.unlock()
    }

    private static let tokenCountMarker = Data("\"token_count\"".utf8)
    private static let turnContextMarker = Data("\"turn_context\"".utf8)

    private func parseFile(_ fileURL: URL, fileDate: Date?, initial: CachedFile?, startOffset: UInt64, readLimit: UInt64?) -> CachedFile {
        var result = initial ?? CachedFile()
        var currentModel = result.currentModel
        var previousCumulativeUsage = result.previousCumulativeUsage

        let fractionalTimestampFormatter = ISO8601DateFormatter()
        fractionalTimestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime]

        let iterator = FileLineSequence(url: fileURL, startOffset: startOffset, readLimit: readLimit).makeIterator()
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
                        let day = Calendar.current.startOfDay(for: eventDate)
                        result.dailyTotals[day, default: 0] += usage.total

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
        parsedByteCount += iterator.bytesRead
        result.currentModel = currentModel
        result.previousCumulativeUsage = previousCumulativeUsage
        result.canAppend = iterator.lastLineTerminated && readLimit == iterator.bytesRead
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
