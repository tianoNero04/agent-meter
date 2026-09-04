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
                    // 粗野主义超粗黑体报头
                    HStack(spacing: 3) {
                        Text("AGENT")
                            .font(.system(size: 10, weight: .black, design: .default))
                        Text("METER")
                            .font(.system(size: 10, weight: .black, design: .default))
                    }
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.primaryText)

                    // 杂志期号与克莱因蓝系统就绪指示
                    HStack(spacing: 3) {
                        Text("VOL.26 //")
                            .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("SYS.OK")
                            .font(.system(size: 6.5, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.kleinBlue)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("打开设置 (Settings)")
    }
}

/// 自适应粗野主义黑色几何 Logo（采用模板模式渲染为深邃纯黑）
struct AgentMeterLogo: View {
    var body: some View {
        Group {
            if let logo = BundleImages.logoWhite {
                Image(nsImage: logo)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(AppTheme.primaryText)
            } else {
                Image("AgentMeterLogoWhite", bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .scaledToFit()
        .accessibilityLabel("Agent Meter")
    }
}
