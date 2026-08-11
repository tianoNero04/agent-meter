import Foundation

/// Provider 启用与选中状态的不含 UI 语义的值对象。
/// 由 `ProviderSettingsStore` 读写，`Features/Navigation` 负责映射为导航状态。
struct ProviderPreferences: Equatable {
    var enabledProviders: Set<Provider>
    var selectedProvider: Provider?

    init(
        enabledProviders: Set<Provider> = Set(Provider.allCases),
        selectedProvider: Provider? = .codex
    ) {
        self.enabledProviders = enabledProviders
        self.selectedProvider = selectedProvider
    }
}
