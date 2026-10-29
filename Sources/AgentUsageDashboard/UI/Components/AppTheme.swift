import SwiftUI

/// 中性黑灰、绿色功能强调与账号卡片光感颜色。
enum AppTheme {
    static let background = Color(white: 17.0 / 255) // #111111
    static let surface = Color(white: 25.0 / 255) // #191919
    static let elevated = Color(white: 34.0 / 255) // #222222
    static let primaryText = Color(white: 238.0 / 255) // #EEEEEE
    static let secondaryText = Color(white: 180.0 / 255) // #B4B4B4
    static let tertiaryText = Color(white: 155.0 / 255)
    static let hairline = Color(white: 48.0 / 255)
    static let hairlineBright = Color(white: 112.0 / 255)
    static let accent = Color(red: 61.0 / 255, green: 214.0 / 255, blue: 140.0 / 255) // #3DD68C
    static let accentBorder = accent
    static let selection = Color(red: 19.0 / 255, green: 45.0 / 255, blue: 33.0 / 255)
    static let heroBackground = Color(red: 5.0 / 255, green: 15.0 / 255, blue: 15.0 / 255)
    static let heroGreen = Color(red: 20.0 / 255, green: 105.0 / 255, blue: 67.0 / 255)
    static let heroLight = Color(red: 166.0 / 255, green: 250.0 / 255, blue: 211.0 / 255)
    static let success = accent
    static let warning = Color(red: 1, green: 0.72, blue: 0.35)
    // 用量构成以明度与文字标签区分，缓存保留品牌绿。
    static let chartInput = Color(white: 0.68)
    static let chartOutput = Color(white: 0.40)
    static let gridCornerRadius: CGFloat = 4
    static let geometricRadius: CGFloat = 4
    static let cardCornerRadius: CGFloat = 4
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

    /// 所有 Provider 共用绿色功能强调色。
    var accentColor: Color { AppTheme.accent }
}

