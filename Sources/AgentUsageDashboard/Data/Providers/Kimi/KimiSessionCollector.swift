import Foundation

struct KimiLocalData {
    var tokenUsage: TokenUsage
    var dailyBuckets: [DailyTokenBucket]
    var models: [ModelUsage]
}

/// Kimi Code 本机会话采集器。
/// 按文件缓存解析结果（修改时间 + 文件大小为键），只有变化的文件才重新解析。
final class KimiSessionCollector {
    private struct CachedFile {
        var modificationDate: Date?
        var fileSize: Int?
        var usage: TokenUsage = .zero
        var dailyEvents: [(date: Date, usage: TokenUsage)] = []
        var modelTotals: [String: TokenUsage] = [:]
    }

    private let sessionsURL: URL
    private let lock = NSLock()
    private var cache: [String: CachedFile] = [:]

    /// 实际执行过完整解析的文件数，供测试验证增量行为。
    private(set) var parsedFileCount = 0

    init(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        sessionsURL = homeURL.appendingPathComponent(".kimi-code/sessions", isDirectory: true)
    }

    func collect() -> KimiLocalData {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return KimiLocalData(tokenUsage: .zero, dailyBuckets: [], models: [])
        }

        var total = TokenUsage.zero
        var dailyEvents: [(date: Date, usage: TokenUsage)] = []
        var modelTotals: [String: TokenUsage] = [:]
        var seen: Set<String> = []

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "wire.jsonl" {
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
        }

        pruneCache(keeping: seen)

        return KimiLocalData(
            tokenUsage: total,
            dailyBuckets: DailyTokenAggregation.buckets(from: dailyEvents),
            models: modelTotals.map { ModelUsage(model: $0.key, usage: $0.value) }
                .sorted { $0.usage.total > $1.usage.total }
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

        for line in FileLineSequence(url: fileURL) {
            // 逐行释放 JSONSerialization 产生的 autorelease 对象。
            autoreleasepool {
                guard let object = JSONSupport.jsonObject(from: line) else { return }
                let usageObject = (object["usage"] as? [String: Any])
                    ?? JSONSupport.object(object, path: ["event", "usage"])
                guard let usage = JSONSupport.kimiTokenUsage(usageObject) else { return }

                result.usage = result.usage + usage
                result.dailyEvents.append((
                    date: JSONSupport.eventDate(object) ?? fileDate ?? .now,
                    usage: usage
                ))
                let model = JSONSupport.string(object["modelAlias"])
                    ?? JSONSupport.string(object["model"])
                    ?? "Kimi"
                result.modelTotals[model, default: .zero] = result.modelTotals[model, default: .zero] + usage
            }
        }
        return result
    }
}
