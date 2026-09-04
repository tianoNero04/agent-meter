import SwiftUI

/// 完整菜单面板窗口视图：目前满足“先不写任何内容，有个框就行”的骨架占位
struct FullMenuView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        ZStack {
            // 象牙白温润底色
            AppTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                // 顶部刊头指示标
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.kleinBlue)

                        Text("[MENU // FULL.PANEL]")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(AppTheme.primaryText)
                    }

                    Spacer()

                    Text("FRAME ONLY // CONTENT RESERVED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                // 核心预留线框区域（具备 4pt 紧凑微圆角、1.25pt 纯黑边框与 2pt 硬阴影）
                VStack(spacing: 12) {
                    Spacer()

                    Image(systemName: "square.dashed")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(AppTheme.kleinBlue.opacity(0.8))

                    VStack(spacing: 4) {
                        Text("[MENU.CONTAINER.FRAME]")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(AppTheme.primaryText)

                        Text("预留粗野主义菜单线框结构 · 内容待接入")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .panelBackground()
            }
            .padding(18)
        }
        .frame(minWidth: 480, minHeight: 340)
        .preferredColorScheme(.light)
    }
}
