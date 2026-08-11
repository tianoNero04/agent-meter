import Foundation

protocol ProviderSettingsStore {
    func load() -> ProviderPreferences
    func save(_ preferences: ProviderPreferences)
}
