import SwiftUI
import AppKit

enum PopoverSection: Hashable {
    case provider(Provider)
}

/// 瑞士国际主义菜单栏弹窗主视图：390×425 pt 精确海报网格结构
struct PopoverView: View {
    @ObservedObject var model: DashboardModel
    @Environment(\.openWindow) private var openWindow
    @State private var selectedSection: PopoverSection = .provider(.codex)
    @State private var slideEdge: Edge = .trailing

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左侧外凸书签栏（悬浮外挂于主卡片外缘）
            ProviderBookmarkTabs(
                model: model,
                selectedProvider: selectedProvider
            ) { provider in
                selectProvider(provider)
            }
            .zIndex(1)

            // 右侧主面板网格卡片
            VStack(spacing: 0) {
                // 顶部杂志报头（Masthead）通栏（含品牌与右上角控制中心按钮）
                PopoverTopBar(openWindow: openWindow)

                // 报头下方通栏 0.75pt 精确发丝基准线
                Rectangle()
                    .fill(AppTheme.hairline)
                    .frame(height: 0.75)

                // 下方三大结构化网格模块面板
                ProviderPanel(
                    snapshot: model.snapshot(for: selectedProvider),
                    // 手动点击校准时无视冷却，强制发起远端查询
                    refresh: { model.refreshAccountOnPanelOpen(force: true) },
                    slideEdge: slideEdge
                )
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 17)
            }
            .frame(width: 390, height: 425)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 0.75)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 6)
        }
        .frame(width: 425, height: 425)
        .preferredColorScheme(.dark)
        // 捕获菜单栏弹窗的宿主 NSWindow，彻底剥离系统级浅色外框与毛玻璃背景，实现左侧外凸书签的纯粹透明悬浮
        .background(
            WindowAccessor { window in
                MenuBarDismissManager.shared.register(window: window)
            }
        )
        .onAppear {
            restoreSelection()
            normalizeSelection()
            // 严格“打开面板才查询，平时不查询”，带 30 秒防刷智能冷却
            model.refreshAccountOnPanelOpen(force: false)
        }
        .onDisappear {
            // 面板关闭时立即中断在途网络请求，彻底消除后台网络开销
            model.cancelAccountRefresh()
        }
        .onChange(of: model.navigation.visibleProviders) { _ in normalizeSelection() }
    }

    private func selectProvider(_ provider: Provider) {
        let order = model.navigation.visibleProviders
        let oldIndex = order.firstIndex(of: selectedProvider) ?? 0
        let newIndex = order.firstIndex(of: provider) ?? 0
        slideEdge = newIndex >= oldIndex ? .trailing : .leading
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedSection = .provider(provider)
        }
        model.selectProvider(provider)
    }

    private var selectedProvider: Provider {
        if case let .provider(provider) = normalizedSection { return provider }
        return model.navigation.visibleProviders.first ?? .codex
    }

    private var normalizedSection: PopoverSection {
        guard case let .provider(provider) = selectedSection else { return selectedSection }
        return model.navigation.isEnabled(provider) ? .provider(provider) : .provider(.codex)
    }

    private func normalizeSelection() {
        guard case let .provider(provider) = selectedSection, !model.navigation.isEnabled(provider) else { return }
        selectedSection = .provider(model.navigation.visibleProviders.first ?? .codex)
    }

    private func restoreSelection() {
        guard let provider = model.navigation.selectedProvider, model.navigation.isEnabled(provider) else { return }
        selectedSection = .provider(provider)
    }
}

/// 杂志报头（Masthead Top Bar）：左侧刊头品牌标示，右上角面板图标启动完整菜单
struct PopoverTopBar: View {
    let openWindow: OpenWindowAction

    var body: some View {
        HStack(spacing: 0) {
            // 刊头品牌区
            PopoverHeader(openSettings: openWindow)

            Spacer(minLength: 10)

            // 右上角面板图标：点击后启动统一控制中心总窗口
            PanelMenuButton {
                // 预先声明窗口开启，防止弹窗收起过程误切回 accessory 模式引起 Dock 图标闪烁
                DockPolicyManager.shared.windowWillOpen("master")
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "master")
                // 打开主页面后，自动关闭当前菜单栏小窗
                MenuBarDismissManager.shared.dismiss()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }
}

/// 右上角面板图标按钮：呈现严谨瑞士国际主义微圆角与悬停反馈，点击激活并启动完整菜单
struct PanelMenuButton: View {
    let openMenu: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: openMenu) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? AppTheme.surface : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isHovered ? AppTheme.hairline.opacity(0.8) : AppTheme.hairline.opacity(0.4), lineWidth: 0.75)
                    )

                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovered ? AppTheme.primaryText : AppTheme.secondaryText)
            }
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("启动控制中心总窗口 (Control Center)")
    }
}

/// 用于在 SwiftUI 视图生命周期内捕获其宿主 NSWindow，并消除系统浅色毛玻璃与外圈边框的桥接组件
private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configureTransparentWindow(window)
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                configureTransparentWindow(window)
                onWindow(window)
            }
        }
    }

    private func configureTransparentWindow(_ window: NSWindow) {
        // 强制采用暗色外观，避免浅色模式下系统渲染浅灰外框
        window.appearance = NSAppearance(named: .darkAqua)
        window.isOpaque = false
        window.backgroundColor = .clear
        // 禁用系统大矩形整体阴影，改由 SwiftUI 卡片层自主精确投射自然拟物阴影
        window.hasShadow = false

        // 递归剥离系统托管的 VisualEffect 毛玻璃和浅色图层背景
        if let contentView = window.contentView {
            stripBackground(contentView)
            if let superview = contentView.superview {
                stripBackground(superview)
            }
        }
    }

    private func stripBackground(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        if let effectView = view as? NSVisualEffectView {
            effectView.isHidden = true
        }
        for subview in view.subviews {
            stripBackground(subview)
        }
    }
}
