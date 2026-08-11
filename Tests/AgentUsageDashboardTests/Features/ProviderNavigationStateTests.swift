import XCTest
@testable import AgentUsageDashboardKit

final class NavigationTests: XCTestCase {
    func testProviderNavigationShowsAllProvidersByDefault() {
        let navigation = ProviderNavigationState()

        XCTAssertEqual(navigation.visibleProviders, [.codex, .kimiCode])
        XCTAssertEqual(navigation.selectedProvider, .codex)
    }

    func testDisablingProviderRemovesItsTabAndSelectsAnotherProvider() {
        var navigation = ProviderNavigationState(selectedProvider: .kimiCode)

        navigation.setProviderEnabled(.kimiCode, false)

        XCTAssertEqual(navigation.visibleProviders, [.codex])
        XCTAssertEqual(navigation.selectedProvider, .codex)
    }
}
