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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

                if model.navigation.visibleProviders.isEmpty {
                    PopoverProvidersEmptyState()
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProviderPanel(
                        snapshot: model.snapshot(for: selectedProvider),
                        isRefreshing: model.isRefreshing,
                        lastRefresh: model.lastRefresh,
                        refresh: { model.refreshAccountOnPanelOpen(force: true) },
                        slideEdge: slideEdge
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 9)
                    .padding(.bottom, 6)
                }

                // 底部构成主义发丝标语与系统状态指示栏（小横杠数量与选中位置同顶部 Provider 动态联动）
                PopoverFooter(
                    providers: model.navigation.visibleProviders,
                    selectedProvider: selectedProvider
                ) { provider in
                    selectProvider(provider)
                }
            }
        }
        .frame(width: 390, height: 425)
        .preferredColorScheme(.dark)
        .tint(AppTheme.accent)
        .accentColor(AppTheme.accent)
        // 捕获菜单栏弹窗的宿主 NSWindow，以便打开主页面时可精确瞬时收起
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
        guard model.navigation.visibleProviders.contains(provider) else { return }
        let order = model.navigation.visibleProviders
        let oldIndex = order.firstIndex(of: selectedProvider) ?? 0
        let newIndex = order.firstIndex(of: provider) ?? 0
        slideEdge = newIndex >= oldIndex ? .trailing : .leading
        if reduceMotion {
            selectedSection = .provider(provider)
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedSection = .provider(provider)
            }
        }
        model.selectProvider(provider)
    }

    private var selectedProvider: Provider {
        if case let .provider(provider) = normalizedSection { return provider }
        return model.navigation.visibleProviders.first ?? .codex
    }

    private var normalizedSection: PopoverSection {
        guard case let .provider(provider) = selectedSection,
              !model.navigation.visibleProviders.contains(provider),
              let first = model.navigation.visibleProviders.first else { return selectedSection }
        return .provider(first)
    }

    private func normalizeSelection() {
        guard case let .provider(provider) = selectedSection else { return }
        if !model.navigation.visibleProviders.contains(provider),
           let first = model.navigation.visibleProviders.first {
            selectedSection = .provider(first)
        }
    }

    private func restoreSelection() {
        guard let provider = model.navigation.selectedProvider,
              model.navigation.visibleProviders.contains(provider) else { return }
        selectedSection = .provider(provider)
    }
}

private struct PopoverProvidersEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(AppTheme.tertiaryText)
            Text("没有已启用的服务商")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text("请在控制中心的“服务商与诊断”中重新启用。")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
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
            HStack(spacing: 9) {
                ProviderNavigationBar(model: model, selection: $selection, onSelect: onSelect)

                // 极简 0.75pt 垂直微发丝分割线
                Rectangle()
                    .fill(AppTheme.hairline)
                    .frame(width: 0.75, height: 16)

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
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }
}

/// 右上角面板图标按钮：呈现严谨构成主义微圆角与绿色悬停反馈，点击激活并启动完整控制中心
struct PanelMenuButton: View {
    let openMenu: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: openMenu) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                    .fill(isHovered ? AppTheme.surface : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                            .stroke(isHovered ? AppTheme.accentBorder : AppTheme.hairline.opacity(0.5), lineWidth: 0.75)
                    )

                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovered ? AppTheme.accent : AppTheme.secondaryText)
            }
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("打开控制中心")
        .accessibilityLabel("打开控制中心")
    }
}

/// 底部构成主义发丝标语与系统状态微能量指示（小横杠数量与选中位置同顶部 Provider 动态联动）
struct PopoverFooter: View {
    var providers: [Provider] = [.codex, .kimiCode]
    var selectedProvider: Provider = .codex
    var onSelect: ((Provider) -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 0.75)
            HStack {
                Text(providers.isEmpty ? "未启用服务商" : selectedProvider.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.tertiaryText)
                Spacer()
                HStack(spacing: 0) {
                    ForEach(providers, id: \.self) { provider in
                        let isSelected = provider == selectedProvider
                        Button { onSelect?(provider) } label: {
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(isSelected ? AppTheme.accent : Color.white.opacity(0.14))
                                .frame(width: isSelected ? 8 : 4, height: 2)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("切换到 \(provider.displayName)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: selectedProvider)
            }
            .padding(.horizontal, 14)
            .frame(height: 27)
        }
    }
}

/// 用于在 SwiftUI 视图生命周期内捕获其宿主 NSWindow 的轻量级桥接组件
private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onWindow(window)
            }
        }
    }
}
