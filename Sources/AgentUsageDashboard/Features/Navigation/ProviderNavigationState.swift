import Foundation

/// 顶部 Provider 导航的应用界面状态，由 `ProviderPreferences` 映射而来。
struct ProviderNavigationState: Equatable {
    private(set) var enabledProviders: Set<Provider>
    private(set) var selectedProvider: Provider?

    var visibleProviders: [Provider] {
        Provider.allCases.filter { enabledProviders.contains($0) }
    }

    init(enabledProviders: Set<Provider> = Set(Provider.allCases), selectedProvider: Provider? = .codex) {
        self.enabledProviders = enabledProviders
        let visible = Provider.allCases.filter { enabledProviders.contains($0) }
        self.selectedProvider = selectedProvider.flatMap { visible.contains($0) ? $0 : visible.first }
    }

    init(preferences: ProviderPreferences) {
        self.init(
            enabledProviders: preferences.enabledProviders,
            selectedProvider: preferences.selectedProvider ?? .codex
        )
    }

    var preferences: ProviderPreferences {
        ProviderPreferences(enabledProviders: enabledProviders, selectedProvider: selectedProvider)
    }

    mutating func setProviderEnabled(_ provider: Provider, _ enabled: Bool) {
        if enabled {
            enabledProviders.insert(provider)
            if selectedProvider == nil { selectedProvider = provider }
        } else {
            enabledProviders.remove(provider)
            if selectedProvider == provider { selectedProvider = visibleProviders.first }
        }
    }

    mutating func selectProvider(_ provider: Provider) {
        guard enabledProviders.contains(provider) else { return }
        selectedProvider = provider
    }

    func isEnabled(_ provider: Provider) -> Bool {
        enabledProviders.contains(provider)
    }
}
