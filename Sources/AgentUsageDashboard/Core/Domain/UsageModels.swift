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

/// Token 用量统计结构（对齐 cc-switch 的 UsageSummary 指标体系）
struct TokenUsage: Codable, Hashable {
    var input: Int = 0
    var cachedInput: Int = 0
    var output: Int = 0
    var reasoning: Int = 0

    /// 真实总消耗 Token（输入 + 缓存 + 输出 + 推理）
    var total: Int { input + cachedInput + output + reasoning }

    /// 缓存命中率（对齐 cc-switch：cachedInput / (input + cachedInput)，范围 0.0 ~ 1.0）
    var cacheHitRate: Double {
        let totalInput = input + cachedInput
        guard totalInput > 0 else { return 0.0 }
        return Double(cachedInput) / Double(totalInput)
    }

    static let zero = TokenUsage()

    static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            input: lhs.input + rhs.input,
            cachedInput: lhs.cachedInput + rhs.cachedInput,
            output: lhs.output + rhs.output,
            reasoning: lhs.reasoning + rhs.reasoning
        )
    }

    /// 增量减法运算符（用于从累计值计算单次增量 delta）
    static func - (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            input: max(0, lhs.input - rhs.input),
            cachedInput: max(0, lhs.cachedInput - rhs.cachedInput),
            output: max(0, lhs.output - rhs.output),
            reasoning: max(0, lhs.reasoning - rhs.reasoning)
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
