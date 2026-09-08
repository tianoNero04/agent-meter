import AppKit
import Foundation

/// 负责在从菜单栏弹窗打开独立主窗口（如设置/控制中心）时，自动收起并关闭菜单栏小窗
@MainActor
public final class MenuBarDismissManager {
    /// 全局共享单例
    public static let shared = MenuBarDismissManager()

    /// 弱引用记录当前展示中的小窗窗口
    private weak var popoverWindow: NSWindow?

    public init() {}

    /// 注册当前小窗窗口引用
    public func register(window: NSWindow) {
        self.popoverWindow = window
    }

    /// 执行关闭菜单栏小窗操作
    public func dismiss() {
        // 1. 优先通过已注册的窗口实例立即隐藏，实现零延迟收起
        if let window = popoverWindow {
            window.orderOut(nil)
        }

        // 2. 遍历查找所有属于 MenuBarExtra 的窗口并隐藏，确保无遗留小窗
        for window in NSApplication.shared.windows {
            let className = window.className
            if className.contains("MenuBarExtra") {
                window.orderOut(nil)
            }
        }

        // 3. 检查系统状态栏窗口，若按钮处于选中/开启状态则同步重置
        for window in NSApplication.shared.windows {
            if window.className.contains("NSStatusBarWindow"),
               let statusItem = window.value(forKey: "statusItem") as? NSStatusItem,
               let button = statusItem.button {
                if button.state != .off {
                    button.performClick(nil)
                }
                button.isHighlighted = false
                button.state = .off
            }
        }
    }
}
