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
    func testInitialStateRemainsAccessoryWithoutWindows() {
        let fake = FakeActivationPolicyApplier()
        let manager = DockPolicyManager(applier: fake, debounceNanoseconds: 0)

        // 初始状态下应用处于 accessory 附属模式，不展示 Dock 栏图标
        XCTAssertEqual(fake.policy, .accessory)
        XCTAssertTrue(manager.activeWindows.isEmpty)
    }

    func testWindowWillOpenAndDidAppearSwitchesToRegularAndActivates() {
        let fake = FakeActivationPolicyApplier()
        let manager = DockPolicyManager(applier: fake, debounceNanoseconds: 0)

        // 模拟用户点击右上角面板/设置按钮打开独立窗口
        manager.windowWillOpen("menu")

        XCTAssertTrue(manager.activeWindows.contains("menu"))
        XCTAssertEqual(fake.policy, .regular)
        XCTAssertEqual(fake.activateCallCount, 1)

        // 窗口展示完成
        manager.windowDidAppear("menu")
        XCTAssertEqual(fake.policy, .regular)
    }

    func testWindowCloseRevertsToAccessoryAfterDebounce() async {
        let fake = FakeActivationPolicyApplier()
        let manager = DockPolicyManager(applier: fake, debounceNanoseconds: 10_000_000)

        manager.windowWillOpen("menu")
        manager.windowDidAppear("menu")
        XCTAssertEqual(fake.policy, .regular)

        // 模拟关闭窗口
        manager.windowDidDisappear("menu")
        XCTAssertFalse(manager.activeWindows.contains("menu"))

        // 等待防抖结束
        try? await Task.sleep(nanoseconds: 25_000_000)

        // 所有窗口已关闭，平滑恢复为 accessory 模式
        XCTAssertEqual(fake.policy, .accessory)
    }

    func testMultipleWindowsMaintainRegularUntilAllClosed() async {
        let fake = FakeActivationPolicyApplier()
        let manager = DockPolicyManager(applier: fake, debounceNanoseconds: 10_000_000)

        manager.windowDidAppear("menu")
        manager.windowDidAppear("settings")
        XCTAssertEqual(fake.policy, .regular)

        // 关闭其中一个窗口
        manager.windowDidDisappear("menu")
        try? await Task.sleep(nanoseconds: 25_000_000)

        // 仍有 settings 窗口开启，保持 regular
        XCTAssertEqual(fake.policy, .regular)

        // 关闭最后一个窗口
        manager.windowDidDisappear("settings")
        try? await Task.sleep(nanoseconds: 25_000_000)

        // 全部关闭后恢复为 accessory
        XCTAssertEqual(fake.policy, .accessory)
    }

    func testHasVisibleRegularWindowPreventsRevertingToAccessory() async {
        let fake = FakeActivationPolicyApplier()
        fake.hasVisibleWindow = true
        let manager = DockPolicyManager(applier: fake, debounceNanoseconds: 10_000_000)

        manager.windowDidAppear("menu")
        manager.windowDidDisappear("menu")

        try? await Task.sleep(nanoseconds: 25_000_000)

        // 由于系统底层仍存在可见普通窗口，保持 regular
        XCTAssertEqual(fake.policy, .regular)
    }
}
