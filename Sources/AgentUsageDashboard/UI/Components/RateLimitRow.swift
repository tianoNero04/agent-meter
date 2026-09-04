import SwiftUI

/// 瑞士风格额度行组件：左侧图标与类型标识，中央为标志性分段标尺，右侧并置巨幅等宽百分比与重置信息
struct RateLimitRow: View {
    let window: RateLimitWindow
    var accent: Color = AppTheme.codex

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // 工业规格图标
            QuotaRowIcon(windowMinutes: window.windowMinutes)

            // 窗口属性与题注
            VStack(alignment: .leading, spacing: 1.5) {
                Text(window.label)
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundStyle(AppTheme.primaryText)
                Text(windowSubtitle)
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(width: 60, alignment: .leading)

            // 标志性视觉元素：瑞士高精度分段刻度能量标尺
            SwissSegmentedGauge(remainingPercent: window.remainingPercent, accent: accent)
                .frame(maxWidth: .infinity)

            // 核心数值：大幅等宽百分比读数
            Text("\(window.remainingPercent, specifier: "%.0f")%")
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 48, alignment: .trailing)

            // 竖向发丝分割线与右侧重置倒计时
            if let resetsAt = window.resetsAt {
                Rectangle()
                    .fill(AppTheme.hairline)
                    .frame(width: 0.75, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text("RESETS")
                        .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(resetDateText(from: resetsAt))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                    Text(countdownText(to: resetsAt))
                        .font(.system(size: 7.5, weight: .regular, design: .default))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(width: 58, alignment: .leading)
            }
        }
    }

    private func resetDateText(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: date)
        return String(format: "%d/%d %02d:%02d", components.month ?? 0, components.day ?? 0, components.hour ?? 0, components.minute ?? 0)
    }

    private func countdownText(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        if seconds == 0 { return "即刻重置" }
        let days = seconds / 86400, hours = (seconds % 86400) / 3600, minutes = (seconds % 3600) / 60
        if days > 0 { return "余 \(days)天\(hours)时" }
        if hours > 0 { return "余 \(hours)时\(minutes)分" }
        return "余 \(max(1, minutes))分"
    }

    private var windowSubtitle: String {
        switch window.windowMinutes {
        case 300: return "LIMIT 05H"
        case 10080: return "LIMIT 07D"
        case let minutes?: return "LIMIT \(minutes)M"
        default: return "ACCOUNT"
        }
    }
}

/// 瑞士高精度分段刻度标尺（Signature Element）：将额度容量划分为 20 格微型精密量块
struct SwissSegmentedGauge: View {
    let remainingPercent: Double
    var accent: Color = AppTheme.codex

    private let totalSegments: Int = 20

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let spacing: CGFloat = 1.5
            let segmentWidth = max(2, (availableWidth - CGFloat(totalSegments - 1) * spacing) / CGFloat(totalSegments))
            let filledCount = Int(round((remainingPercent / 100.0) * Double(totalSegments)))

            HStack(spacing: spacing) {
                ForEach(0..<totalSegments, id: \.self) { index in
                    let isFilled = index < filledCount
                    let isHead = index == filledCount - 1 && filledCount > 0
                    Rectangle()
                        .fill(
                            isFilled
                                ? (isHead ? Color.white : accent)
                                : Color.white.opacity(0.08)
                        )
                        .frame(width: segmentWidth, height: 6.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 6.5)
    }
}
