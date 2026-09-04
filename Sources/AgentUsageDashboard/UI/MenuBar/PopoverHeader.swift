import SwiftUI

/// 杂志报头刊头品牌组件（Masthead Branding）：呈现严谨出版物风格的品牌标题与系统期号
struct PopoverHeader: View {
    let openSettings: OpenWindowAction

    var body: some View {
        Button { openSettings(id: "settings") } label: {
            HStack(spacing: 8) {
                // 极简白色几何 Logo
                AgentMeterLogo()
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 0) {
                    // 报头重字重大写标
                    HStack(spacing: 3) {
                        Text("AGENT")
                            .font(.system(size: 10, weight: .heavy, design: .default))
                        Text("METER")
                            .font(.system(size: 10, weight: .heavy, design: .default))
                    }
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.primaryText)

                    // 杂志期号与系统就绪指示
                    Text("VOL.26 // SYS.OK")
                        .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.secondaryText)
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
