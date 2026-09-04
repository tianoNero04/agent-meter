import XCTest
import AppKit
@testable import AgentUsageDashboardKit

/// 模拟系统激活策略应用器，用于单测隔离
@MainActor
private final class FakeActivationPolicyApplier: ActivationPolicyApplying {
    var policy: NSApplication.ActivationPolicy = .accessory
    var activateCallCount = 0
    var hasVisibleWindow = false

    func currentPolicy() -> NSApplication.ActivationPolicy {
        policy
    }

    func setPolicy(_ policy: NSApplication.ActivationPolicy) -> Bool {
        self.policy = policy
        return true
    }

    func activate() {
        activateCallCount += 1
    }

    func hasVisibleRegularWindow() -> Bool {
        hasVisibleWindow
    }
}

@MainActor
final class DockPolicyManagerTests: XCTestCase {
    func testPopoverAppearSwitchesToRegularAndActivates() {
        let fake = FakeActivationPolicyApplier()
        let manager = DockPolicyManager(applier: fake, debounceNanoseconds: 0)

        XCTAssertEqual(fake.policy, .accessory)
        XCTAssertFalse(manager.isPopoverVisible)

        // 模拟打开菜单弹窗
        manager.popoverDidAppear()

        XCTAssertTrue(manager.isPopoverVisible)
        XCTAssertEqual(fake.policy, .regular)
        XCTAssertEqual(fake.activateCallCount, 1)
    }

    func testPopoverDisappearRevertsToAccessoryWhenNoWindowsOpen() async {
        let fake = FakeActivationPolicyApplier()
        let manager = DockPolicyManager(applier: fake, debounceNanoseconds: 10_000_000)

        manager.popoverDidAppear()
        XCTAssertEqual(fake.policy, .regular)

        // 模拟收起菜单弹窗
        manager.popoverDidDisappear()
        XCTAssertFalse(manager.isPopoverVisible)

        // 等待防抖触发
        try? await Task.sleep(nanoseconds: 25_000_000)

        XCTAssertEqual(fake.policy, .accessory)
    }

    func testWindowWillOpenAndDidAppearKeepsRegularPolicy() async {
        let fake = FakeActivationPolicyApplier()
        let manager = DockPolicyManager(applier: fake, debounceNanoseconds: 10_000_000)

        manager.popoverDidAppear()

        // 模拟点击面板按钮，预先锁定完整菜单窗口开启
        manager.windowWillOpen("menu")
        XCTAssertTrue(manager.activeWindows.contains("menu"))
        XCTAssertEqual(fake.policy, .regular)

        // 弹窗关闭，但完整菜单窗口仍在开启中
        manager.popoverDidDisappear()
        manager.windowDidAppear("menu")

        try? await Task.sleep(nanoseconds: 25_000_000)

        // 依然应保持 regular 模式，Dock 图标不闪烁
        XCTAssertEqual(fake.policy, .regular)

        // 模拟关闭完整菜单窗口
        manager.windowDidDisappear("menu")
        XCTAssertFalse(manager.activeWindows.contains("menu"))

        try? await Task.sleep(nanoseconds: 25_000_000)

        // 所有窗口已关闭，恢复为 accessory 模式
        XCTAssertEqual(fake.policy, .accessory)
    }

    func testHasVisibleRegularWindowPreventsRevertingToAccessory() async {
        let fake = FakeActivationPolicyApplier()
        fake.hasVisibleWindow = true
        let manager = DockPolicyManager(applier: fake, debounceNanoseconds: 10_000_000)

        manager.popoverDidAppear()
        manager.popoverDidDisappear()

        try? await Task.sleep(nanoseconds: 25_000_000)

        // 由于系统底层检测到仍有可见普通窗口，保持 regular
        XCTAssertEqual(fake.policy, .regular)
    }
}
