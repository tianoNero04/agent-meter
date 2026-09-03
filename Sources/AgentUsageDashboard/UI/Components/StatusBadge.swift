import SwiftUI

/// 瑞士极简技术状态标签：呈现清晰的点阵状态与等宽状态码
struct StatusBadge: View {
    let status: ProviderStatus

    var body: some View {
        HStack(spacing: 5) {
            // 严谨几何微型状态原点
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)

            // 全大写等宽状态码
            Text(status.displayText.uppercased())
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(status == .connected ? AppTheme.primaryText : AppTheme.secondaryText)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 0.5)
        )
    }

    private var statusColor: Color {
        switch status {
        case .connected: return AppTheme.success
        case .error: return AppTheme.warning
        default: return AppTheme.secondaryText
        }
    }
}
