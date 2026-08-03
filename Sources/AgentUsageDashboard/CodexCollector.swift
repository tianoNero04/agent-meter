import Foundation

struct CodexLocalData {
    var tokenUsage: TokenUsage
    var models: [ModelUsage]
    var windows: [RateLimitWindow]
    var latestModel: String?
}

struct CodexLogCollector {
    private let sessionsURL: URL

    init(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        sessionsURL = homeURL.appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    func collect() -> CodexLocalData {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return CodexLocalData(tokenUsage: .zero, models: [], windows: [], latestModel: nil)
        }

        var total = TokenUsage.zero
        var modelTotals: [String: TokenUsage] = [:]
        var latestWindows: [RateLimitWindow] = []
        var latestRateLimitDate: Date?
        var latestModel: String?
        let fractionalTimestampFormatter = ISO8601DateFormatter()
        fractionalTimestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime]

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let fileDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? nil
            var currentModel: String?

            for line in content.split(whereSeparator: { $0.isNewline }) {
                guard let object = JSONSupport.jsonObject(from: String(line)) else { continue }
                let payload = object["payload"] as? [String: Any] ?? object
                let eventType = JSONSupport.string(payload["type"])

                if eventType == "turn_context" {
                    currentModel = JSONSupport.string(payload["model"])
                        ?? JSONSupport.string(payload["model_provider"])
                }

                if eventType == "token_count" {
                    if let delta = JSONSupport.object(payload, path: ["info", "last_token_usage"]),
                       let usage = JSONSupport.tokenUsage(delta) {
                        total = total + usage
                        let model = currentModel ?? JSONSupport.string(payload["model"]) ?? "Codex"
                        modelTotals[model, default: .zero] = modelTotals[model, default: .zero] + usage
                        latestModel = model
                    }

                    if let rateLimits = JSONSupport.object(payload, path: ["rate_limits"]) {
                        let timestamp = JSONSupport.string(object["timestamp"])
                            .flatMap { fractionalTimestampFormatter.date(from: $0) ?? timestampFormatter.date(from: $0) }
                            ?? fileDate
                            ?? .distantPast
                        if latestRateLimitDate == nil || timestamp >= latestRateLimitDate! {
                            latestWindows = parseWindows(rateLimits)
                            latestRateLimitDate = timestamp
                        }
                    }
                }
            }
        }

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
