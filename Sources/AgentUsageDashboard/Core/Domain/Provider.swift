import Foundation

/// AI 服务提供商或本地 Agent 标识枚举
enum Provider: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    // 核心官方直连与日志采集提供商
    case codex = "codex"
    case kimiCode = "kimiCode"

    // 本地已检测到的主流开发智能体与工具链
    case antigravity = "antigravity"
    case claude = "claude"
    case cursor = "cursor"
    case vscode = "vscode"
    case grok = "grok"
    case opencode = "opencode"
    case openclaw = "openclaw"
    case hermes = "hermes"
    case pi = "pi"
    case ollama = "ollama"

    /// 内置核心官方提供商列表
    static let coreProviders: [Provider] = [.codex, .kimiCode]

    var id: String { rawValue }

    /// 映射 LocalToolEnvironment 的标识符
    var toolId: String {
        switch self {
        case .codex: return "codex"
        case .kimiCode: return "kimi"
        case .antigravity: return "antigravity"
        case .claude: return "claude"
        case .cursor: return "cursor"
        case .vscode: return "vscode"
        case .grok: return "grok"
        case .opencode: return "opencode"
        case .openclaw: return "openclaw"
        case .hermes: return "hermes"
        case .pi: return "pi"
        case .ollama: return "ollama"
        }
    }

    /// 由本地环境扫描工具 ID 快速映射 Provider
    init?(toolId: String) {
        switch toolId.lowercased() {
        case "codex": self = .codex
        case "kimi", "kimi-code", "kimicode": self = .kimiCode
        case "antigravity": self = .antigravity
        case "claude": self = .claude
        case "cursor": self = .cursor
        case "vscode", "code": self = .vscode
        case "grok": self = .grok
        case "opencode": self = .opencode
        case "openclaw": self = .openclaw
        case "hermes": self = .hermes
        case "pi": self = .pi
        case "ollama": self = .ollama
        default: return nil
        }
    }

    /// 用户界面展示的品牌或工具友好名称
    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .kimiCode: return "Kimi Code"
        case .antigravity: return "Antigravity"
        case .claude: return "Claude Code"
        case .cursor: return "Cursor"
        case .vscode: return "VS Code"
        case .grok: return "Grok"
        case .opencode: return "OpenCode"
        case .openclaw: return "OpenClaw"
        case .hermes: return "Hermes"
        case .pi: return "Pi"
        case .ollama: return "Ollama"
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
