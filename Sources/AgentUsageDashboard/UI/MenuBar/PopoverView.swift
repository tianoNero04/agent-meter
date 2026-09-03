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
                // 顶部杂志报头（Masthead）通栏
                PopoverTopBar(model: model, selection: $selectedSection, openSettings: openWindow) { provider in
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

/// 杂志报头（Masthead Top Bar）：左侧刊头品牌标示，右侧平铺瑞士选项卡
struct PopoverTopBar: View {
    @ObservedObject var model: DashboardModel
    @Binding var selection: PopoverSection
    let openSettings: OpenWindowAction
    let onSelect: (Provider) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 刊头品牌区
            PopoverHeader(openSettings: openSettings)

            Spacer(minLength: 16)

            // 选项卡切换区
            ProviderNavigationBar(model: model, selection: $selection, onSelect: onSelect)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }
}
