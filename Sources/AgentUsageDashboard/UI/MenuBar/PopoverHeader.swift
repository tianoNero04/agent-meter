import SwiftUI

struct PopoverHeader: View {
    let openSettings: OpenWindowAction

    var body: some View {
        Button {
            DockPolicyManager.shared.windowWillOpen("master")
            NSApp.activate(ignoringOtherApps: true)
            openSettings(id: "master")
            MenuBarDismissManager.shared.dismiss()
        } label: {
            HStack(spacing: 8) {
                AgentMeterLogo()
                    .frame(width: 17, height: 17)
                Text("AGENT METER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(AppTheme.primaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("打开控制中心")
        .accessibilityLabel("打开 Agent Meter 控制中心")
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
