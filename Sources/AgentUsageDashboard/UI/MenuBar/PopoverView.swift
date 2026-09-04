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
        ZStack {
            // 纯粹深墨黑底色（消退背景噪声）
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部杂志报头（Masthead）通栏（含品牌、选项卡与右上角面板图标）
                PopoverTopBar(model: model, selection: $selectedSection, openWindow: openWindow) { provider in
                    selectProvider(provider)
                }

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
        }
        .frame(width: 390, height: 425)
        .preferredColorScheme(.dark)
        .onAppear {
            // 打开弹窗菜单时动态唤起 Dock 栏图标并激活应用
            DockPolicyManager.shared.popoverDidAppear()
            restoreSelection()
            normalizeSelection()
            // 严格“打开面板才查询，平时不查询”，带 30 秒防刷智能冷却
            model.refreshAccountOnPanelOpen(force: false)
        }
        .onDisappear {
            // 菜单弹窗收起时通知管理器进行防抖恢复
            DockPolicyManager.shared.popoverDidDisappear()
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

/// 杂志报头（Masthead Top Bar）：左侧刊头品牌标示，右侧平铺瑞士选项卡，右上角面板图标启动完整菜单
struct PopoverTopBar: View {
    @ObservedObject var model: DashboardModel
    @Binding var selection: PopoverSection
    let openWindow: OpenWindowAction
    let onSelect: (Provider) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 刊头品牌区
            PopoverHeader(openSettings: openWindow)

            Spacer(minLength: 10)

            // 选项卡切换区与完整菜单面板图标
            HStack(spacing: 8) {
                ProviderNavigationBar(model: model, selection: $selection, onSelect: onSelect)

                // 极简 0.75pt 垂直微发丝分割线
                Rectangle()
                    .fill(AppTheme.hairline)
                    .frame(width: 0.75, height: 16)

                // 右上角面板图标：点击后启动完整菜单窗口
                PanelMenuButton {
                    // 预先声明窗口开启，防止弹窗收起过程误切回 accessory 模式引起 Dock 图标闪烁
                    DockPolicyManager.shared.windowWillOpen("menu")
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "menu")
                }
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
        .help("启动完整菜单 (Full Menu)")
    }
}
