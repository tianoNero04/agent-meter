import SwiftUI
import AppKit

enum PopoverSection: Hashable {
    case provider(Provider)
}

struct PopoverView: View {
    @ObservedObject var model: DashboardModel
    @Environment(\.openWindow) private var openWindow
    @State private var selectedSection: PopoverSection = .provider(.codex)
    @State private var slideEdge: Edge = .trailing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            PopoverMaterialBackground()
                .ignoresSafeArea()
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PopoverTopBar(model: model, selection: $selectedSection, openWindow: openWindow) { provider in
                    selectProvider(provider)
                }

                if model.navigation.visibleProviders.isEmpty {
                    PopoverProvidersEmptyState()
                        .padding(16)
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
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }

                PopoverFooter(
                    providers: model.navigation.visibleProviders,
                    selectedProvider: selectedProvider
                ) { provider in
                    selectProvider(provider)
                }
            }
        }
        .frame(width: 404, height: 472)
        .preferredColorScheme(.dark)
        .tint(AppTheme.accent)
        .accentColor(AppTheme.accent)
        .background(
            WindowAccessor { window in
                window.isOpaque = false
                window.backgroundColor = .clear
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

struct PopoverTopBar: View {
    @ObservedObject var model: DashboardModel
    @Binding var selection: PopoverSection
    let openWindow: OpenWindowAction
    let onSelect: (Provider) -> Void

    var body: some View {
        HStack(spacing: 12) {
            PopoverHeader(openSettings: openWindow)
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                ProviderNavigationBar(model: model, selection: $selection, onSelect: onSelect)
                PanelMenuButton {
                    DockPolicyManager.shared.windowWillOpen("master")
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "master")
                    MenuBarDismissManager.shared.dismiss()
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }
}

struct PanelMenuButton: View {
    let openMenu: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: openMenu) {
            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isHovered ? AppTheme.accent : AppTheme.secondaryText)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(isHovered ? 0.10 : 0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(isHovered ? 0.20 : 0.09), lineWidth: 0.75)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("打开控制中心")
        .accessibilityLabel("打开控制中心")
    }
}

struct PopoverFooter: View {
    var providers: [Provider] = [.codex, .kimiCode]
    var selectedProvider: Provider = .codex
    var onSelect: ((Provider) -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            Text(providers.isEmpty ? "未启用服务商" : selectedProvider.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            HStack(spacing: 0) {
                ForEach(providers, id: \.self) { provider in
                    let isSelected = provider == selectedProvider
                    Button { onSelect?(provider) } label: {
                        Capsule()
                            .fill(isSelected ? AppTheme.accent : Color.white.opacity(0.18))
                            .frame(width: isSelected ? 14 : 4, height: 3)
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
        .padding(.horizontal, 16)
        .frame(height: 32)
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
