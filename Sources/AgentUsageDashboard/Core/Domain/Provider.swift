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
