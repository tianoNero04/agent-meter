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

    func testDetectedProvidersDynamicallyExpandsVisibleProvidersWhenEnabled() {
        var navigation = ProviderNavigationState()
        // 模拟本地环境检测探测到了 Antigravity 与 Claude
        navigation.updateDetectedProviders([.codex, .kimiCode, .antigravity, .claude])
        navigation.setProviderEnabled(.antigravity, true)
        navigation.setProviderEnabled(.claude, true)

        XCTAssertTrue(navigation.visibleProviders.contains(.antigravity))
        XCTAssertTrue(navigation.visibleProviders.contains(.claude))
        XCTAssertEqual(navigation.visibleProviders.count, 4)
    }

    func testDisabledProviderIsHiddenFromVisibleProvidersEvenIfDetected() {
        var navigation = ProviderNavigationState()
        navigation.updateDetectedProviders([.codex, .kimiCode, .antigravity])
        // 用户在服务商页面中关闭 Antigravity
        navigation.setProviderEnabled(.antigravity, false)

        XCTAssertFalse(navigation.visibleProviders.contains(.antigravity))
        XCTAssertEqual(navigation.visibleProviders, [.codex, .kimiCode])
    }

    func testInitialSelectionIgnoresCLIDetection() {
        let navigation = ProviderNavigationState(
            enabledProviders: [.codex, .kimiCode],
            detectedProviders: [.codex],
            selectedProvider: .kimiCode
        )

        XCTAssertEqual(navigation.selectedProvider, .kimiCode)
        XCTAssertEqual(navigation.visibleProviders, [.codex, .kimiCode])
    }

    func testActiveProviderFallsBackToFirstEnabledProvider() {
        let navigation = ProviderNavigationState(
            enabledProviders: [.kimiCode],
            detectedProviders: [],
            selectedProvider: .codex
        )

        XCTAssertEqual(navigation.activeProvider, .kimiCode)
    }

    func testEnabledProviderRemainsVisibleWhenCLIIsNotDetected() {
        var navigation = ProviderNavigationState()
        navigation.updateDetectedProviders([.codex])

        XCTAssertEqual(navigation.visibleProviders, [.codex, .kimiCode])
        XCTAssertTrue(navigation.isEnabled(.kimiCode))
        XCTAssertFalse(navigation.isDetected(.kimiCode))
    }
}
