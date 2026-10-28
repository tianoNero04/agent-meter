import SwiftUI

struct RateLimitRow: View {
    let window: RateLimitWindow
    var accent: Color = AppTheme.accent

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 10) {
                QuotaRowIcon(windowMinutes: window.windowMinutes)
                Text(window.label)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(window.remainingPercent, specifier: "%.0f")%")
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
            }
            HStack(spacing: 10) {
                QuotaGauge(remainingPercent: window.remainingPercent, accent: accent)
                if let resetsAt = window.resetsAt {
                    HStack(spacing: 4) {
                        Text("重置")
                            .foregroundStyle(AppTheme.secondaryText)
                        if window.windowMinutes == 300 {
                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                Text(countdownText(to: resetsAt, now: context.date))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .monospacedDigit()
                            }
                        } else {
                            Text(resetDateText(from: resetsAt))
                                .foregroundStyle(AppTheme.primaryText)
                                .monospacedDigit()
                        }
                    }
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .fixedSize()
                }
            }
            .padding(.leading, 45)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func resetDateText(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: date)
        return String(format: "%d/%d %02d:%02d", components.month ?? 0, components.day ?? 0, components.hour ?? 0, components.minute ?? 0)
    }

    private func countdownText(to date: Date, now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds == 0 { return "即刻重置" }
        let days = seconds / 86400, hours = (seconds % 86400) / 3600, minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days)天\(hours)小时" }
        if hours > 0 { return "\(hours)小时\(minutes)分" }
        return "\(max(1, minutes))分钟"
    }
}

struct QuotaGauge: View {
    let remainingPercent: Double
    var accent: Color = AppTheme.accent

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.white.opacity(0.09))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(accent)
                        .frame(width: proxy.size.width * min(max(remainingPercent / 100, 0), 1))
                }
        }
        .frame(height: 6)
    }
}
