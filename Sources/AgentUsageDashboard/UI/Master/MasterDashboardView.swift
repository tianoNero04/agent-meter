import SwiftUI

/// 统一控制台总窗口根视图：集成 ReactBits app-sidebar-1 风格固定侧边栏与动态功能工作区
struct MasterDashboardView: View {
    @ObservedObject var model: DashboardModel
    @State private var selectedSection: MasterSection = .overview
    @State private var latencyBadge: String? = nil
    @State private var modelCountBadge: String? = nil

    init(model: DashboardModel, initialSection: MasterSection = .overview) {
        self.model = model
        self._selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：固定 220pt 现代深色侧边栏（像素级复刻 ReactBits app-sidebar-1）
            AppSidebarView(
                selection: $selectedSection,
                latencyBadge: latencyBadge,
                modelCountBadge: modelCountBadge
            )

            // 右侧：选定分区的动态工作区
            ZStack(alignment: .topTrailing) {
                AppTheme.background.ignoresSafeArea()

                Group {
                    switch selectedSection {
                    case .overview:
                        // 默认进入：ReactBits monitoring-8 风格 Token 用量大盘与下钻看板
                        MonitoringDashboardView(model: model)
                    case .general:
                        GeneralSettingsTab(model: model)
                    case .providers:
                        ProvidersDiagnosticsTab(model: model, latencyBadge: $latencyBadge)
                    case .pricing:
                        ModelPricingTab(model: model)
                    case .alerts:
                        AlertsSettingsTab(model: model)
                    case .models:
                        ScrollView {
                            ModelUsageTab(model: model)
                                .padding(.top, 44)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                        }
                    case .savings:
                        PromptSavingsTab(model: model)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // 窗口右上角全局常驻：日夜模式切换按钮（位于外框上方，任意页面皆可见）
                ThemeToggleButton()
                    .padding(.top, 12)
                    .padding(.trailing, 20)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .preferredColorScheme(.dark)
        .navigationTitle("")
        .background(WindowTitlebarConfigurator())
        .onAppear {
            // 打开控制台总窗口时动态在 Dock 栏唤起图标并激活应用
            DockPolicyManager.shared.windowDidAppear("master")

            // 初始化模型数徽标
            let currentProvider = model.navigation.selectedProvider ?? .codex
            let count = model.snapshot(for: currentProvider).localModels.count
            if count > 0 {
                modelCountBadge = "\(count)"
            }
        }
        .onDisappear {
            // 关闭总窗口时通知管理器评估并恢复为 accessory 纯菜单栏模式
            DockPolicyManager.shared.windowDidDisappear("master")
        }
    }
}

/// 原生窗口配置器：彻底隐藏标题栏文字、实现一体化暗黑透明标题栏与背景任意拖拽移动
private struct WindowTitlebarConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.isMovableByWindowBackground = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
