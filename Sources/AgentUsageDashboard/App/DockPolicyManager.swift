import AppKit
import Foundation

/// 激活策略设置与系统交互抽象协议，便于脱离真实 AppKit 运行环境进行单测
public protocol ActivationPolicyApplying: AnyObject, Sendable {
    /// 获取当前系统激活策略
    @MainActor func currentPolicy() -> NSApplication.ActivationPolicy
    /// 设置系统激活策略
    @MainActor @discardableResult func setPolicy(_ policy: NSApplication.ActivationPolicy) -> Bool
    /// 激活当前应用至前台
    @MainActor func activate()
    /// 检查是否有非状态栏的可见常规窗口
    @MainActor func hasVisibleRegularWindow() -> Bool
}

/// 默认系统 AppKit 激活策略实现
public final class SystemActivationPolicyApplier: ActivationPolicyApplying {
    public init() {}

    @MainActor
    public func currentPolicy() -> NSApplication.ActivationPolicy {
        NSApplication.shared.activationPolicy()
    }

    @MainActor
    @discardableResult
    public func setPolicy(_ policy: NSApplication.ActivationPolicy) -> Bool {
        NSApplication.shared.setActivationPolicy(policy)
    }

    @MainActor
    public func activate() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @MainActor
    public func hasVisibleRegularWindow() -> Bool {
        NSApplication.shared.windows.contains { window in
            // 过滤掉系统状态栏窗口及不可成为主窗口的辅助小部件
            window.isVisible && window.canBecomeMain
        }
    }
}

/// 负责动态管理应用在 macOS 系统中的激活策略与 Dock 栏图标展示。
/// 主菜单栏展开时默认保持轻量 `.accessory` 附属模式，不唤起 Dock 栏图标；
/// 仅当从右上角按钮打开独立窗口（如“完整菜单”、“详细统计”、“设置”）时，才动态将激活策略切换为 `.regular`，唤起 Dock 栏图标；
/// 当所有独立窗口关闭后，平滑防抖恢复为 `.accessory` 模式，从 Dock 栏与应用切换器中隐匿。
@MainActor
public final class DockPolicyManager {
    /// 全局共享单例
    public static let shared = DockPolicyManager()

    /// 策略应用器抽象
    private let applier: ActivationPolicyApplying

    /// 跟踪当前处于打开状态的独立窗口标识集合
    public private(set) var activeWindows: Set<String> = []

    /// 防抖任务：防止在窗口销毁与新建的微小过渡期内发生 Dock 图标突兀跳动
    private var revertTask: Task<Void, Never>?

    /// 策略重置防抖延迟时间（纳秒），默认 150 毫秒
    private let debounceNanoseconds: UInt64

    public init(
        applier: ActivationPolicyApplying = SystemActivationPolicyApplier(),
        debounceNanoseconds: UInt64 = 150_000_000
    ) {
        self.applier = applier
        self.debounceNanoseconds = debounceNanoseconds
        setupWindowObserver()
    }

    /// 监听窗口即将关闭通知作为二次状态同步保障
    private func setupWindowObserver() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateWindowStatus()
            }
        }
    }

    /// 预告即将打开独立窗口（例如用户点击了右上角面板/设置按钮）
    public func windowWillOpen(_ identifier: String) {
        revertTask?.cancel()
        revertTask = nil
        activeWindows.insert(identifier)
        applyPolicy(regular: true)
    }

    /// 独立窗口已完成展示
    public func windowDidAppear(_ identifier: String) {
        revertTask?.cancel()
        revertTask = nil
        activeWindows.insert(identifier)
        applyPolicy(regular: true)
    }

    /// 独立窗口已关闭
    public func windowDidDisappear(_ identifier: String) {
        activeWindows.remove(identifier)
        schedulePolicyEvaluation()
    }

    /// 检查系统当前实际窗口可见性并重新评估策略
    public func evaluateWindowStatus() {
        let hasWindow = applier.hasVisibleRegularWindow()
        if !hasWindow && activeWindows.isEmpty {
            schedulePolicyEvaluation()
        }
    }

    /// 延迟防抖评估激活策略，确保交互过渡平滑无闪烁
    private func schedulePolicyEvaluation() {
        revertTask?.cancel()
        revertTask = Task { @MainActor in
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }

            let shouldBeRegular = !activeWindows.isEmpty || applier.hasVisibleRegularWindow()
            applyPolicy(regular: shouldBeRegular)
        }
    }

    /// 执行激活策略切换
    private func applyPolicy(regular: Bool) {
        let current = applier.currentPolicy()
        if regular {
            if current != .regular {
                _ = applier.setPolicy(.regular)
            }
            applier.activate()
        } else {
            if current != .accessory {
                _ = applier.setPolicy(.accessory)
            }
        }
    }
}
