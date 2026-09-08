import XCTest
import AppKit
@testable import AgentUsageDashboardKit

@MainActor
final class MenuBarDismissManagerTests: XCTestCase {
    // 验证调用 dismiss 时能够安全处理未注册或空窗口状态，不发生崩溃
    func testDismissWithoutRegisteredWindowDoesNotCrash() {
        let manager = MenuBarDismissManager()
        manager.dismiss()
    }

    // 验证注册窗口后，调用 dismiss 能够成功将窗口 orderOut 隐藏
    func testDismissHidesRegisteredWindow() {
        let manager = MenuBarDismissManager()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.makeKeyAndOrderFront(nil)
        XCTAssertTrue(window.isVisible, "窗口初始化后应处于可见状态")

        manager.register(window: window)
        manager.dismiss()

        XCTAssertFalse(window.isVisible, "执行 dismiss 后，已注册的窗口应被立即 orderOut 隐藏")
    }

    // 验证从 DockPolicyManager.windowWillOpen 打开独立主窗口时，会自动执行小窗收起逻辑
    func testDockPolicyManagerWindowWillOpenTriggersDismiss() {
        let manager = MenuBarDismissManager.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.makeKeyAndOrderFront(nil)
        manager.register(window: window)

        // 模拟用户点击打开 master 主窗口
        DockPolicyManager.shared.windowWillOpen("master")

        XCTAssertFalse(window.isVisible, "打开 master 独立主窗口时，菜单栏小窗应自动被关闭隐藏")
    }
}
