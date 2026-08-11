import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.043, green: 0.063, blue: 0.090)
    static let surface = Color(red: 0.075, green: 0.106, blue: 0.145)
    static let primaryText = Color(red: 0.957, green: 0.969, blue: 0.984)
    static let secondaryText = Color(red: 0xD0 / 255, green: 0xCF / 255, blue: 0xCF / 255)
    static let codex = Color(red: 0.424, green: 0.714, blue: 1.000)
    static let kimi = Color(red: 0.765, green: 0.608, blue: 1.000)
    static let success = Color(red: 0.306, green: 0.839, blue: 0.643)
    static let warning = Color(red: 0.961, green: 0.718, blue: 0.357)
}

extension Provider {
    var iconName: String { self == .codex ? "terminal.fill" : "moon.stars.fill" }
    var accentColor: Color { self == .codex ? AppTheme.codex : AppTheme.kimi }
}
