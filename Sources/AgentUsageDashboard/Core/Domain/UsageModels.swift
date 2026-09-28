import Foundation

struct RateLimitWindow: Codable, Identifiable, Hashable {
    /// 额度窗口唯一标识符
    var id: String
    /// 已消耗百分比 (0.0 ~ 100.0)
    var usedPercent: Double
    /// 窗口总时长分钟数（如 300 分钟、10080 分钟）
    var windowMinutes: Int?
    /// 额度重置时间点
    var resetsAt: Date?
    /// 可选的友好展示名称（如 "Claude"、"Gemini"），为空时根据时长显示默认标签
    var name: String? = nil

    /// 剩余可用百分比
    var remainingPercent: Double {
        max(0, min(100, 100 - usedPercent))
    }

    /// 标签显示文本：若指定自定义名称则优先返回，否则按窗口分钟数或 ID 展示
    var label: String {
        if let name = name, !name.isEmpty {
            return name
        }
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
