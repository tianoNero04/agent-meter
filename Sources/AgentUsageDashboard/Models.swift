import Foundation

enum Provider: String, Codable, CaseIterable, Identifiable, Hashable {
    case codex
    case kimiCode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .kimiCode: return "Kimi Code"
        }
    }
}

enum ProviderStatus: String, Codable {
    case connected
    case notInstalled
    case notAuthenticated
    case unavailable
    case error

    var displayText: String {
        switch self {
        case .connected: return "已连接"
        case .notInstalled: return "未安装"
        case .notAuthenticated: return "未登录"
        case .unavailable: return "暂不可用"
        case .error: return "采集失败"
        }
    }
}

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

struct AccountTokenUsage: Codable, Hashable {
    var lifetimeTokens: Int?
    var peakDailyTokens: Int?
    var dailyBuckets: [DailyTokenBucket]?
}

struct AccountIdentity: Codable, Hashable {
    var planType: String?
    var email: String?
}

struct ProviderSnapshot: Codable, Identifiable, Hashable {
    var provider: Provider
    var status: ProviderStatus
    var account: AccountIdentity?
    var windows: [RateLimitWindow]
    var accountUsage: AccountTokenUsage?
    var localTokenUsage: TokenUsage
    var localModels: [ModelUsage]
    var source: String
    var collectedAt: Date
    var errorMessage: String?

    var id: Provider { provider }

    static func empty(_ provider: Provider) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: provider,
            status: .unavailable,
            account: nil,
            windows: [],
            accountUsage: nil,
            localTokenUsage: .zero,
            localModels: [],
            source: "none",
            collectedAt: .now,
            errorMessage: nil
        )
    }
}

struct DashboardSnapshot: Codable, Hashable {
    var collectedAt: Date
    var providers: [ProviderSnapshot]
}

struct PersistedDashboard: Codable {
    var current: DashboardSnapshot
    var history: [DashboardSnapshot]
}
