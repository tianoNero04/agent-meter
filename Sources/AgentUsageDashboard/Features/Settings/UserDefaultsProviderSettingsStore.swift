import Foundation

/// 基于 UserDefaults 的 Provider 设置仓库。
/// 键名保持 `enabledProviders` / `selectedProvider` 不变。
struct UserDefaultsProviderSettingsStore: ProviderSettingsStore {
    private enum Keys {
        static let enabledProviders = "enabledProviders"
        static let selectedProvider = "selectedProvider"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ProviderPreferences {
        let enabled: Set<Provider>
        if let values = defaults.array(forKey: Keys.enabledProviders) as? [String] {
            enabled = Set(values.compactMap(Provider.init(rawValue:)))
        } else {
            enabled = Set(Provider.allCases)
        }
        let selected = defaults.string(forKey: Keys.selectedProvider).flatMap(Provider.init(rawValue:))
        return ProviderPreferences(enabledProviders: enabled, selectedProvider: selected)
    }

    func save(_ preferences: ProviderPreferences) {
        defaults.set(preferences.enabledProviders.map(\.rawValue), forKey: Keys.enabledProviders)
        defaults.set(preferences.selectedProvider?.rawValue, forKey: Keys.selectedProvider)
    }
}
