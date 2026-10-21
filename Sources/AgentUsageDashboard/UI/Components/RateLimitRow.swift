import SwiftUI

/// 紧凑额度行：窗口、剩余百分比与重置时间共用一条阅读路径。
struct RateLimitRow: View {
    let window: RateLimitWindow
    var accent: Color = AppTheme.accent

    var body: some View {
        HStack(spacing: 10) {
            QuotaRowIcon(windowMinutes: window.windowMinutes)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(window.label).font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 4)
                    Text("\(window.remainingPercent, specifier: "%.0f")%")
                        .font(.system(size: 17, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(AppTheme.primaryText)
                SwissSegmentedGauge(remainingPercent: window.remainingPercent, accent: accent)
            }
            if let resetsAt = window.resetsAt {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(window.windowMinutes == 300 ? "距离重置" : "重置时间")
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(window.windowMinutes == 300 ? countdownText(to: resetsAt) : resetDateText(from: resetsAt))
                        .foregroundStyle(AppTheme.primaryText)
                        .monospacedDigit()
                }
                .font(.system(size: 11))
                .lineLimit(1)
                .frame(width: 92, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
    }

    private func resetDateText(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: date)
        return String(format: "%d/%d %02d:%02d", components.month ?? 0, components.day ?? 0, components.hour ?? 0, components.minute ?? 0)
    }

    private func countdownText(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        if seconds == 0 { return "即刻重置" }
        let days = seconds / 86400, hours = (seconds % 86400) / 3600, minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days)天\(hours)小时" }
        if hours > 0 { return "\(hours)小时\(minutes)分" }
        return "\(max(1, minutes))分钟"
    }
}

struct SwissSegmentedGauge: View {
    let remainingPercent: Double
    var accent: Color = AppTheme.accent

    private let totalSegments: Int = 20

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let spacing: CGFloat = 1.5
            let segmentWidth = max(0, (availableWidth - CGFloat(totalSegments - 1) * spacing) / CGFloat(totalSegments))
            let filledCount = Int(round((remainingPercent / 100.0) * Double(totalSegments)))

            HStack(spacing: spacing) {
                ForEach(0..<totalSegments, id: \.self) { index in
                    let isFilled = index < filledCount
                    RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                        .fill(
                            isFilled
                                ? accent
                                : Color.white.opacity(0.08)
                        )
                        .frame(width: segmentWidth, height: 9.0)

                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 9.0)
    }
}
