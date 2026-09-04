import SwiftUI

/// 完整菜单面板窗口视图：目前满足“先不写任何内容，有个框就行”的骨架占位
struct FullMenuView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        ZStack {
            // 深墨黑背景
            AppTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                // 顶部刊头指示标
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.codex)

                        Text("[MENU // FULL.PANEL]")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(AppTheme.primaryText)
                    }

                    Spacer()

                    Text("FRAME ONLY // CONTENT RESERVED")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                // 核心预留线框区域（具备 6pt 微圆角、发丝边框与网格背景）
                VStack(spacing: 12) {
                    Spacer()

                    Image(systemName: "square.dashed")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(AppTheme.tertiaryText)

                    VStack(spacing: 4) {
                        Text("[MENU.CONTAINER.FRAME]")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.secondaryText)

                        Text("预留菜单线框结构 · 内容待接入")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .panelBackground()
            }
            .padding(18)
        }
        .frame(minWidth: 480, minHeight: 340)
        .preferredColorScheme(.dark)
        .onAppear {
            // 打开完整菜单窗口时动态保持 Dock 栏图标展示
            DockPolicyManager.shared.windowDidAppear("menu")
        }
        .onDisappear {
            // 关闭完整菜单窗口时通知管理器重新评估
            DockPolicyManager.shared.windowDidDisappear("menu")
        }
    }
}
