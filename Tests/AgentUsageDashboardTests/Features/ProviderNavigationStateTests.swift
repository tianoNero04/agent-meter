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

    func testUndetectedProviderIsHiddenFromVisibleProvidersEvenIfEnabled() {
        var navigation = ProviderNavigationState()
        // 本地环境仅检测到了 Codex，未检测到 Kimi
        navigation.updateDetectedProviders([.codex])

        // 即使设置中开启了 Kimi，未检测到的提供商也绝不在浮窗菜单栏显示
        XCTAssertEqual(navigation.visibleProviders, [.codex])
    }
}
