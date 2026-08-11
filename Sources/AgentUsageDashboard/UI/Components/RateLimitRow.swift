import SwiftUI

struct RateLimitRow: View {
    let window: RateLimitWindow
    var accent: Color = AppTheme.codex
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            QuotaRowIcon(windowMinutes: window.windowMinutes)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(window.label).font(.system(size: 11, weight: .regular)).foregroundStyle(AppTheme.primaryText)
                        Text(windowSubtitle).font(.system(size: 7, weight: .regular, design: .monospaced)).tracking(0.5).foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Text("\(window.remainingPercent, specifier: "%.0f")%").font(.system(size: 18, weight: .regular, design: .monospaced)).foregroundStyle(AppTheme.primaryText)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(LinearGradient(colors: [accent.opacity(0.72), accent], startPoint: .leading, endPoint: .trailing)).frame(width: proxy.size.width * CGFloat(window.remainingPercent / 100))
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("已用 \(window.usedPercent, specifier: "%.0f")%")
                    Spacer()
                    if let resetsAt = window.resetsAt { Text(resetText(from: resetsAt)) }
                }
                .font(.system(size: 7, design: .monospaced)).foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
    private func resetText(from date: Date) -> String {
        if window.windowMinutes == 10080 { return "重置 \(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))" }
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        if seconds == 0 { return "即将重置" }
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60
        return hours > 0 ? "约 \(hours) 小时 \(minutes) 分钟后" : "约 \(max(1, minutes)) 分钟后"
    }

    private var windowSubtitle: String {
        switch window.windowMinutes {
        case 300: return "5 HOUR LIMIT"
        case 10080: return "WEEKLY LIMIT"
        case let minutes?: return "\(minutes) MINUTE LIMIT"
        default: return "ACCOUNT WINDOW"
        }
    }
}
