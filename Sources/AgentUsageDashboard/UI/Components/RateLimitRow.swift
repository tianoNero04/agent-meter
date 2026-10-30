import SwiftUI

/// 紧凑额度行：窗口、剩余百分比与重置时间共用一条阅读路径。
struct RateLimitRow: View {
    let window: RateLimitWindow
    var accent: Color = AppTheme.accent

    var body: some View {
        HStack(spacing: 8) {
            QuotaRowIcon(windowMinutes: window.windowMinutes)

            VStack(alignment: .leading, spacing: 3) {
                Text(window.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.72))
                    .lineLimit(1)
            }
            .frame(width: 55, alignment: .leading)

            Group {
                if window.windowMinutes == 10080 {
                    ContinuousQuotaGauge(remainingPercent: window.remainingPercent, accent: accent)
                } else {
                    SwissSegmentedGauge(remainingPercent: window.remainingPercent, accent: accent)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(window.remainingPercent, specifier: "%.0f")%")
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                resetDetail
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(width: 85, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .frame(height: 49)
        .background(AppTheme.heroLight.opacity(0.025), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        switch window.windowMinutes {
        case 300: return "本次对话额度"
        case 10080: return "周度使用额度"
        default: return "账号使用额度"
        }
    }

    @ViewBuilder
    private var resetDetail: some View {
        if let resetsAt = window.resetsAt {
            if window.windowMinutes == 300 {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text("\(countdownText(to: resetsAt, now: context.date)) / 5 小时")
                        .monospacedDigit()
                }
            } else {
                Text("重置时间 \(resetDateText(from: resetsAt))")
                    .monospacedDigit()
            }
        } else {
            Text("重置时间未知")
        }
    }

    private func resetDateText(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: date)
        return String(format: "%d/%d %02d:%02d", components.month ?? 0, components.day ?? 0, components.hour ?? 0, components.minute ?? 0)
    }

    private func countdownText(to date: Date, now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds == 0 { return "即刻重置" }
        let days = seconds / 86400, hours = (seconds % 86400) / 3600, minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days) 天 \(hours) 小时" }
        if hours > 0 { return "\(hours) 小时 \(minutes) 分" }
        return "\(max(1, minutes)) 分钟"
    }
}

struct SwissSegmentedGauge: View {
    let remainingPercent: Double
    var accent: Color = AppTheme.accent

    private let totalSegments: Int = 20

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 2
            let segmentWidth = max(0, (proxy.size.width - CGFloat(totalSegments - 1) * spacing) / CGFloat(totalSegments))
            let filledCount = Int(round((min(max(remainingPercent, 0), 100) / 100.0) * Double(totalSegments)))

            HStack(spacing: spacing) {
                ForEach(0..<totalSegments, id: \.self) { index in
                    let isFilled = index < filledCount
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(isFilled ? accent.opacity(0.64 + 0.36 * Double(index) / Double(totalSegments - 1)) : AppTheme.heroLight.opacity(0.055))
                        .overlay {
                            if isFilled && index == filledCount - 1 {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(AppTheme.heroLight.opacity(0.62))
                            }
                        }
                        .shadow(color: isFilled && index == filledCount - 1 ? accent.opacity(0.65) : .clear, radius: 4)
                        .frame(width: segmentWidth, height: 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 10)
    }
}

private struct ContinuousQuotaGauge: View {
    let remainingPercent: Double
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let fraction = min(max(remainingPercent, 0), 100) / 100
            Capsule()
                .fill(AppTheme.heroLight.opacity(0.045))
                .overlay(Capsule().stroke(AppTheme.heroLight.opacity(0.12), lineWidth: 0.6))
                .overlay(alignment: .leading) {
                    if fraction > 0 {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [AppTheme.heroGreen, accent, AppTheme.heroLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: max(10, proxy.size.width * fraction))
                            .shadow(color: accent.opacity(0.48), radius: 4)
                    }
                }
        }
        .frame(height: 10)
    }
}
