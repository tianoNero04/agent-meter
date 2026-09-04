import SwiftUI

/// 粗野主义（Neo-Brutalism）核心主题系统：象牙白背景、纯黑字体、高能量柠檬黄与克莱因蓝
enum AppTheme {
    // 象牙白底色（Warm Ivory，温润纸张感，消除视觉疲劳）
    static let background = Color(red: 0.984, green: 0.976, blue: 0.957) // #FBF9F4
    // 工业卡片纯白表面
    static let surface = Color(red: 1.000, green: 1.000, blue: 1.000)    // #FFFFFF
    // 次级抬升表面（象牙微灰）
    static let elevated = Color(red: 0.949, green: 0.937, blue: 0.914)   // #F2EFE9

    // 核心主题色：高电压柠檬黄（Electric Lemon Yellow）
    static let lemonYellow = Color(red: 0.980, green: 1.000, blue: 0.000) // #FAFF00
    // 核心主题色：国际克莱因蓝（International Klein Blue - IKB）
    static let kleinBlue = Color(red: 0.000, green: 0.184, blue: 0.655)   // #002FA7

    // 纯黑高对比度字体
    static let primaryText = Color(red: 0.000, green: 0.000, blue: 0.000) // #000000
    // 深炭灰题注与技术参数
    static let secondaryText = Color(red: 0.220, green: 0.220, blue: 0.220) // #383838
    // 中性灰辅助说明
    static let tertiaryText = Color(red: 0.450, green: 0.450, blue: 0.450)  // #737373

    // 粗野主义实黑边框色
    static let border = Color.black
    // 细黑线分割线
    static let hairline = Color.black.opacity(0.18)
    // 醒目黑发丝线
    static let hairlineBright = Color.black.opacity(0.40)

    // 全局统一强调色：克莱因蓝（遵循全 Provider 共用视觉系统规则）
    static let codex = kleinBlue
    static let kimi = kleinBlue

    // 正常在线状态（精密墨绿）
    static let success = Color(red: 0.000, green: 0.650, blue: 0.350)
    // 警告/降级状态（粗野主义橙红）
    static let warning = Color(red: 0.920, green: 0.350, blue: 0.050)

    // 粗野主义紧凑硬朗微圆角
    static let gridCornerRadius: CGFloat = 4.0
}

extension Provider {
    var iconName: String { self == .codex ? "terminal.fill" : "moon.stars.fill" }
    // 统一遵循 AGENTS.md 约定：所有 Provider 共用克莱因蓝
    var accentColor: Color { AppTheme.kleinBlue }
}
