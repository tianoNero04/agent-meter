import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        Color(red: 0.035, green: 0.045, blue: 0.075)
            .frame(width: 460, height: 280)
            .overlay(alignment: .topLeading) {
                Text("设置").font(.system(size: 22, weight: .regular, design: .default)).foregroundStyle(AppTheme.primaryText).padding(24)
            }
    }
}
