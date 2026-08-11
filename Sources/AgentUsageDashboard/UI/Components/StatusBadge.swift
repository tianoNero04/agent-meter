import SwiftUI

struct StatusBadge: View {
    let status: ProviderStatus
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(statusColor)
                .frame(width: 6, height: 6)
                .shadow(color: statusColor.opacity(0.45), radius: 3)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.15), lineWidth: 1)
                        .frame(width: 11, height: 11)
                )
            Text(status.displayText).font(.system(size: 10, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
    private var statusColor: Color {
        switch status { case .connected: return AppTheme.success; case .error: return AppTheme.warning; default: return AppTheme.secondaryText }
    }
}
