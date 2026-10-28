import Foundation

struct KimiLocalData {
    var tokenUsage: TokenUsage
    var dailyBuckets: [DailyTokenBucket]
    var models: [ModelUsage]
}

/// Kimi Code 本机会话采集器。
/// 按文件身份缓存汇总结果，完整行后的追加只读取新字节；替换或截断时重建。
final class KimiSessionCollector {
    private struct CachedFile {
        var modificationDate: Date?
        var fileSize: Int?
        var fileIdentifier: NSObject?
        var tailSignature: Data?
        var canAppend = false
        var usage: TokenUsage = .zero
        var dailyTotals: [Date: Int] = [:]
        var modelTotals: [String: TokenUsage] = [:]
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
        sessionsURL = homeURL.appendingPathComponent(".kimi-code/sessions", isDirectory: true)
    }

    func collect() -> KimiLocalData {
        collectionLock.lock()
        defer { collectionLock.unlock() }
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return KimiLocalData(tokenUsage: .zero, dailyBuckets: [], models: [])
        }

        var total = TokenUsage.zero
        var dailyTotals: [Date: Int] = [:]
        var modelTotals: [String: TokenUsage] = [:]
        var seen: Set<String> = []

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "wire.jsonl" {
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
        }

        pruneCache(keeping: seen)

        return KimiLocalData(
            tokenUsage: total,
            dailyBuckets: dailyTotals.map { DailyTokenBucket(startDate: $0.key, tokens: $0.value) }
                .sorted { $0.startDate < $1.startDate },
            models: modelTotals.map { ModelUsage(model: $0.key, usage: $0.value) }
                .sorted { $0.usage.total > $1.usage.total }
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

    private static let usageMarker = Data("\"usage\"".utf8)

    private func parseFile(_ fileURL: URL, fileDate: Date?, initial: CachedFile?, startOffset: UInt64, readLimit: UInt64?) -> CachedFile {
        var result = initial ?? CachedFile()

        let iterator = FileLineSequence(url: fileURL, startOffset: startOffset, readLimit: readLimit).makeIterator()
        while let line = iterator.nextData() {
            guard line.range(of: Self.usageMarker) != nil else { continue }
            // 逐行释放 JSONSerialization 产生的 autorelease 对象。
            autoreleasepool {
                guard let object = JSONSupport.jsonObject(from: line) else { return }
                let usageObject = (object["usage"] as? [String: Any])
                    ?? JSONSupport.object(object, path: ["event", "usage"])
                guard let usage = JSONSupport.kimiTokenUsage(usageObject) else { return }

                result.usage = result.usage + usage
                let day = Calendar.current.startOfDay(for: JSONSupport.eventDate(object) ?? fileDate ?? .now)
                result.dailyTotals[day, default: 0] += usage.total
                let model = JSONSupport.string(object["modelAlias"])
                    ?? JSONSupport.string(object["model"])
                    ?? "Kimi"
                result.modelTotals[model, default: .zero] = result.modelTotals[model, default: .zero] + usage
            }
        }
        parsedByteCount += iterator.bytesRead
        result.canAppend = iterator.lastLineTerminated && readLimit == iterator.bytesRead
        return result
    }
}
