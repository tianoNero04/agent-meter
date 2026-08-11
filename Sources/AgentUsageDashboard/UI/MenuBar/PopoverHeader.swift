import SwiftUI

struct PopoverHeader: View {
    let openSettings: OpenWindowAction

    var body: some View {
        Button { openSettings(id: "settings") } label: {
            HStack(spacing: 8) {
                AgentMeterLogo().frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("AGENT")
                    Text("METER")
                }
                .font(.system(size: 9, weight: .regular, design: .default))
                .tracking(1.2)
                .foregroundStyle(AppTheme.primaryText)
            }
        }
        .buttonStyle(.plain)
        .help("打开设置")
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
