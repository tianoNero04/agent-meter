import AppKit

/// Bundle 位图只解码一次，避免 SwiftUI 每次 body 求值都重新读盘。
enum BundleImages {
    static let navBarBackground: NSImage? = load("NavBarBackground")
    static let cardStackBackground: NSImage? = load("CardStackBackground")
    static let providerIconCodex: NSImage? = load("ProviderIconCodex")
    static let providerIconKimi: NSImage? = load("ProviderIconKimi")

    static func providerIcon(for provider: Provider) -> NSImage? {
        switch provider {
        case .codex: return providerIconCodex
        case .kimiCode: return providerIconKimi
        }
    }
    static let logoWhite: NSImage? = load("AgentMeterLogoWhite")

    private static func load(_ name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
}
