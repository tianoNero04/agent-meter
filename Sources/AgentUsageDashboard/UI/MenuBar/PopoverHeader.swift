import SwiftUI

/// 杂志报头刊头品牌组件（Masthead Branding）：呈现严谨出版物风格的品牌标题与系统期号
struct PopoverHeader: View {
    let openSettings: OpenWindowAction

    var body: some View {
        Button {
            // 点击 Logo 启动统一控制中心总窗口
            DockPolicyManager.shared.windowWillOpen("master")
            NSApp.activate(ignoringOtherApps: true)
            openSettings(id: "master")
            // 打开主页面后，自动关闭当前展开的菜单栏小窗
            MenuBarDismissManager.shared.dismiss()
        } label: {
            HStack(spacing: 8) {
                // 极简白色几何 Logo
                AgentMeterLogo()
                    .frame(width: 18, height: 18)

                // 报头重字重大写品牌标与平面构成索引
                HStack(spacing: 6) {
                    Text("AGENT METER")
                        .font(.system(size: 10.5, weight: .heavy, design: .default))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.primaryText)

                    // 极细垂直发丝线
                    Rectangle()
                        .fill(AppTheme.hairlineBright)
                        .frame(width: 0.75, height: 10)

                    // 构成主义系统参数索引
                    Text("SYS // PRO")
                        .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("打开设置 (Settings)")
    }
}

struct AgentMeterLogo: View {
    var body: some View {
        Group {
            if let logo = BundleImages.logoWhite {
                Image(nsImage: logo)
                    .resizable()
            } else {
                Image("AgentMeterLogoWhite", bundle: .module)
                    .resizable()
            }
        }
        .scaledToFit()
        .accessibilityLabel("Agent Meter")
    }
}
