import Foundation

struct RateLimitWindow: Codable, Identifiable, Hashable {
    var id: String
    var usedPercent: Double
    var windowMinutes: Int?
    var resetsAt: Date?

    var remainingPercent: Double {
        max(0, min(100, 100 - usedPercent))
    }

    var label: String {
        if let minutes = windowMinutes {
            switch minutes {
            case 300: return "5 小时"
            case 10080: return "本周"
            default: return "\(minutes) 分钟"
            }
        }
        return id
    }
}

struct TokenUsage: Codable, Hashable {
    var input: Int = 0
    var cachedInput: Int = 0
    var output: Int = 0
    var reasoning: Int = 0

    var total: Int { input + cachedInput + output + reasoning }

    static let zero = TokenUsage()

    static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            input: lhs.input + rhs.input,
            cachedInput: lhs.cachedInput + rhs.cachedInput,
            output: lhs.output + rhs.output,
            reasoning: lhs.reasoning + rhs.reasoning
        )
    }
}

struct ModelUsage: Codable, Identifiable, Hashable {
    var model: String
    var usage: TokenUsage

    var id: String { model }
}

struct DailyTokenBucket: Codable, Identifiable, Hashable {
    var startDate: Date
    var tokens: Int

    var id: Date { startDate }
}

enum DailyTokenAggregation {
    static func buckets(
        from events: [(date: Date, usage: TokenUsage)],
        calendar: Calendar = .current
    ) -> [DailyTokenBucket] {
        let totals = events.reduce(into: [Date: Int]()) { result, event in
            let day = calendar.startOfDay(for: event.date)
            result[day, default: 0] += event.usage.total
        }
        return totals
            .map { DailyTokenBucket(startDate: $0.key, tokens: $0.value) }
            .sorted { $0.startDate < $1.startDate }
    }
}

struct AccountTokenUsage: Codable, Hashable {
    var lifetimeTokens: Int?
    var peakDailyTokens: Int?
    var dailyBuckets: [DailyTokenBucket]?
}

struct AccountIdentity: Codable, Hashable {
    var planType: String?
    var email: String?
}
