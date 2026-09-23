import SwiftUI

/// 国际主义（Swiss Style）与杂志风核心主题系统
enum AppTheme {
    // 瑞士纯正深黑底色（纯正炭黑 #060709，消除光污染）
    static let background = Color(red: 0.024, green: 0.027, blue: 0.035) // #060709
    // 工业网格模块底色（低饱和沉稳暗黑 #0D0F13）
    static let surface = Color(red: 0.051, green: 0.059, blue: 0.075)    // #0D0F13
    // 次级抬升表面（用于标签、按压态 #13161B）
    static let elevated = Color(red: 0.075, green: 0.086, blue: 0.106)   // #13161B

    // 纯白高对比度文字
    static let primaryText = Color(red: 0.973, green: 0.976, blue: 0.980)
    // 冷银灰题注与技术参数
    static let secondaryText = Color(red: 0.520, green: 0.570, blue: 0.640)
    // 极淡辅助标注色
    static let tertiaryText = Color(red: 0.360, green: 0.400, blue: 0.470)

    // 0.5pt ~ 1pt 精确发丝线分割线
    static let hairline = Color.white.opacity(0.10)
    // 聚焦与高光发丝线
    static let hairlineBright = Color.white.opacity(0.24)

    // 纯正高能荧光绿（Electric Neon Green），平面构成主义核心数据与指示强调色
    static let neonGreen = Color(red: 0.000, green: 1.000, blue: 0.400) // #00FF66
    // 荧光绿微光与环境光晕
    static let neonGreenGlow = Color(red: 0.000, green: 1.000, blue: 0.400).opacity(0.18)
    // 荧光绿边框线
    static let neonGreenBorder = Color(red: 0.000, green: 1.000, blue: 0.400).opacity(0.40)

    // 国际克莱因蓝（保留作为历史引用兼容）
    static let codex = Color(red: 0.000, green: 1.000, blue: 0.400)      // 升级为高能荧光绿
    static let kimi = Color(red: 0.000, green: 1.000, blue: 0.400)

    // 正常在线状态（精密荧光绿点）
    static let success = Color(red: 0.000, green: 1.000, blue: 0.400)
    // 警告/降级状态
    static let warning = Color(red: 1.000, green: 0.600, blue: 0.150)

    // 常用网格圆角（硬朗紧凑的工业微圆角，杜绝过度圆润膨胀）
    static let gridCornerRadius: CGFloat = 6.0
    static let geometricRadius: CGFloat = 4.0
    static let cardCornerRadius: CGFloat = 8.0
}

extension Provider {
    /// 各提供商在 UI 中展示的高清 SF Symbol 矢量图标
    var iconName: String {
        switch self {
        case .codex: return "terminal.fill"
        case .kimiCode: return "sparkles"
        case .antigravity: return "atom"
        case .claude: return "apple.terminal.fill"
        case .cursor: return "cursorarrow.rays"
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .grok: return "bolt.fill"
        case .opencode: return "curlybraces"
        case .openclaw: return "wrench.and.screwdriver.fill"
        case .hermes: return "paperplane.fill"
        case .pi: return "circle.hexagongrid.fill"
        case .ollama: return "cpu"
        }
    }

    /// 统一遵循 AGENTS.md 约定：所有 Provider 共用固定蓝 AppTheme.codex
    var accentColor: Color { AppTheme.codex }
}

