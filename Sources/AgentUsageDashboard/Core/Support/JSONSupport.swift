import Foundation

enum JSONSupport {
    static func object(_ value: Any?, path: [String]) -> [String: Any]? {
        guard let value else { return nil }
        var current: Any? = value
        for key in path {
            guard let dictionary = current as? [String: Any] else { return nil }
            current = dictionary[key]
        }
        return current as? [String: Any]
    }

    static func value(_ value: Any?, path: [String]) -> Any? {
        guard let value else { return nil }
        var current: Any? = value
        for key in path {
            guard let dictionary = current as? [String: Any] else { return nil }
            current = dictionary[key]
        }
        return current
    }

    static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(value) }
        if let value = value as? Double { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    static func string(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    static func dateFromUnixSeconds(_ value: Any?) -> Date? {
        guard let seconds = double(value) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    static func date(_ value: Any?) -> Date? {
        if let date = dateFromUnixSeconds(value) { return date }
        guard let string = string(value) else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return fractional.date(from: string) ?? standard.date(from: string)
    }

    static func eventDate(_ object: [String: Any]) -> Date? {
        date(object["timestamp"])
            ?? date(object["createdAt"])
            ?? date(object["created_at"])
            ?? date(value(object, path: ["event", "timestamp"]))
            ?? date(value(object, path: ["event", "createdAt"]))
            ?? date(object["time"])
    }

    static func tokenUsage(_ object: [String: Any]?) -> TokenUsage? {
        guard let object else { return nil }
        return TokenUsage(
            input: int(object["input_tokens"] ?? object["input"]) ?? 0,
            cachedInput: int(object["cached_input_tokens"] ?? object["input_cache_read"] ?? object["inputCacheRead"]) ?? 0,
            output: int(object["output_tokens"] ?? object["output"]) ?? 0,
            reasoning: int(object["reasoning_output_tokens"] ?? object["reasoning"]) ?? 0
        )
    }

    static func kimiTokenUsage(_ object: [String: Any]?) -> TokenUsage? {
        guard let object else { return nil }
        let cacheCreation = int(object["inputCacheCreation"]) ?? 0
        let inputOther = int(object["inputOther"]) ?? 0
        let cachedInput = int(object["inputCacheRead"]) ?? 0
        let output = int(object["output"]) ?? 0
        guard cacheCreation != 0 || inputOther != 0 || cachedInput != 0 || output != 0 else { return nil }
        return TokenUsage(
            input: cacheCreation + inputOther,
            cachedInput: cachedInput,
            output: output,
            reasoning: 0
        )
    }

    static func jsonObject(from line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
