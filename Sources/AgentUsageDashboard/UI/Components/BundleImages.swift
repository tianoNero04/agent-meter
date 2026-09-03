import AppKit

/// Bundle 位图只解码一次，避免 SwiftUI 每次 body 求值都重新读盘。
enum BundleImages {
    // 各 Provider 专属图标位图
    static let providerIconCodex: NSImage? = load("ProviderIconCodex")
    static let providerIconKimi: NSImage? = load("ProviderIconKimi")

    static func providerIcon(for provider: Provider) -> NSImage? {
        switch provider {
        case .codex: return providerIconCodex
        case .kimiCode: return providerIconKimi
        }
    }
    static let logoWhite: NSImage? = load("AgentMeterLogoWhite")

    /// 菜单栏常驻图标：尺寸设为 18x18 pt，设置 isTemplate = true 以自适应 macOS 系统深浅色外观
    static let menuBarIcon: NSImage? = {
        guard let image = load("AgentMeterLogoWhite") else { return nil }
        let icon = image.copy() as? NSImage ?? image
        icon.size = NSSize(width: 18, height: 18)
        icon.isTemplate = true
        return icon
    }()

    private static func load(_ name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
}
