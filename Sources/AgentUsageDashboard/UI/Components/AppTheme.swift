import SwiftUI

/// 国际主义（Swiss Style）与杂志风核心主题系统
enum AppTheme {
    // 瑞士深墨黑底色（纯正炭黑，消除光污染）
    static let background = Color(red: 0.039, green: 0.047, blue: 0.063) // #0A0C10
    // 工业网格模块底色（低饱和沉稳微蓝黑）
    static let surface = Color(red: 0.067, green: 0.082, blue: 0.110)    // #11151C
    // 次级抬升表面（用于标签、按压态）
    static let elevated = Color(red: 0.098, green: 0.118, blue: 0.157)   // #191E28

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

    // 国际克莱因蓝（International Blue），全局统一强调色
    static let codex = Color(red: 0.040, green: 0.470, blue: 1.000)      // #0A78FF
    static let kimi = Color(red: 0.040, green: 0.470, blue: 1.000)       // 遵循所有 Provider 统一风格规范
    // 正常在线状态（精密绿点）
    static let success = Color(red: 0.000, green: 0.900, blue: 0.600)
    // 警告/降级状态
    static let warning = Color(red: 1.000, green: 0.600, blue: 0.150)

    // 常用网格圆角（硬朗紧凑的工业小圆角）
    static let gridCornerRadius: CGFloat = 6.0
}

extension Provider {
    var iconName: String { self == .codex ? "terminal.fill" : "moon.stars.fill" }
    // 统一遵循 AGENTS.md 约定：所有 Provider 共用固定蓝 AppTheme.codex
    var accentColor: Color { AppTheme.codex }
}
