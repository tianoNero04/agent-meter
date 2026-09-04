import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        Color(red: 0.035, green: 0.045, blue: 0.075)
            .frame(width: 460, height: 280)
            .overlay(alignment: .topLeading) {
                Text("设置").font(.system(size: 22, weight: .regular, design: .default)).foregroundStyle(AppTheme.primaryText).padding(24)
            }
            .onAppear {
                // 打开设置窗口时动态保持 Dock 栏图标展示
                DockPolicyManager.shared.windowDidAppear("settings")
            }
            .onDisappear {
                // 关闭设置窗口时通知管理器重新评估
                DockPolicyManager.shared.windowDidDisappear("settings")
            }
    }
}
