import XCTest
@testable import AgentUsageDashboardKit

final class ProviderSettingsStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "agent-meter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testLoadDefaultsToAllProvidersEnabled() {
        let store = UserDefaultsProviderSettingsStore(defaults: makeDefaults())

        let preferences = store.load()

        XCTAssertEqual(preferences.enabledProviders, Set(Provider.allCases))
        XCTAssertNil(preferences.selectedProvider)
    }

    func testSaveAndLoadRoundTripsPreferences() {
        let store = UserDefaultsProviderSettingsStore(defaults: makeDefaults())
        let preferences = ProviderPreferences(enabledProviders: [.kimiCode], selectedProvider: .kimiCode)

        store.save(preferences)

        XCTAssertEqual(store.load(), preferences)
    }

    func testSavePersistsUnderLegacyUserDefaultsKeys() {
        let defaults = makeDefaults()
        let store = UserDefaultsProviderSettingsStore(defaults: defaults)

        store.save(ProviderPreferences(enabledProviders: [.codex], selectedProvider: .codex))

        XCTAssertEqual(defaults.array(forKey: "enabledProviders") as? [String], ["codex"])
        XCTAssertEqual(defaults.string(forKey: "selectedProvider"), "codex")
    }

    func testNavigationStateMapsFromPreferences() {
        let preferences = ProviderPreferences(enabledProviders: [.kimiCode], selectedProvider: nil)

        let navigation = ProviderNavigationState(preferences: preferences)

        XCTAssertEqual(navigation.visibleProviders, [.kimiCode])
        XCTAssertEqual(navigation.selectedProvider, .kimiCode)
        XCTAssertEqual(navigation.preferences.enabledProviders, [.kimiCode])
    }
}
