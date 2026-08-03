import Foundation

struct KimiLocalData {
    var tokenUsage: TokenUsage
    var models: [ModelUsage]
}

struct KimiLogCollector {
    private let sessionsURL: URL

    init(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        sessionsURL = homeURL.appendingPathComponent(".kimi-code/sessions", isDirectory: true)
    }

    func collect() -> KimiLocalData {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return KimiLocalData(tokenUsage: .zero, models: [])
        }

        var total = TokenUsage.zero
        var modelTotals: [String: TokenUsage] = [:]

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "wire.jsonl" {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            for line in content.split(whereSeparator: { $0.isNewline }) {
                guard let object = JSONSupport.jsonObject(from: String(line)) else { continue }
                let usageObject = (object["usage"] as? [String: Any])
                    ?? JSONSupport.object(object, path: ["event", "usage"])
                guard let usage = JSONSupport.kimiTokenUsage(usageObject) else { continue }

                total = total + usage
                let model = JSONSupport.string(object["modelAlias"])
                    ?? JSONSupport.string(object["model"])
                    ?? "Kimi"
                modelTotals[model, default: .zero] = modelTotals[model, default: .zero] + usage
            }
        }

        return KimiLocalData(
            tokenUsage: total,
            models: modelTotals.map { ModelUsage(model: $0.key, usage: $0.value) }
                .sorted { $0.usage.total > $1.usage.total }
        )
    }
}
