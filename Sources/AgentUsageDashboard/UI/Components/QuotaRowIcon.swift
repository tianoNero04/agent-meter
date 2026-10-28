import SwiftUI

enum QuotaRowIconKind: Equatable {
    case clock
    case calendar
    case generic
}

/// 额度行图标视觉规范：按弹窗标准尺寸（366pt 宽度基准）等比缩放。
struct QuotaRowIconSpec: Equatable {
    let kind: QuotaRowIconKind

    static let backgroundScale: CGFloat = 366 / 732

    var backgroundScale: CGFloat { Self.backgroundScale }
    var ringSize: CGFloat { 70 * Self.backgroundScale }
    var ringBorderWidth: CGFloat { Self.backgroundScale }
    var clockSize: CGFloat { 32 * Self.backgroundScale }
    var clockStrokeWidth: CGFloat { 3 * Self.backgroundScale }
    var calendarSize: CGFloat { 58 * Self.backgroundScale }
    var calendarPointSize: CGFloat { 32 * Self.backgroundScale }
    var genericPointSize: CGFloat { 24 * Self.backgroundScale }
    var glyphVerticalOffset: CGFloat { 2 * Self.backgroundScale }
    let calendarOpacity: Double = 0.88

    init(windowMinutes: Int?) {
        switch windowMinutes {
        case 300: kind = .clock
        case 10080: kind = .calendar
        default: kind = .generic
        }
    }
}

struct QuotaRowIcon: View {
    let spec: QuotaRowIconSpec

    init(windowMinutes: Int?) {
        spec = QuotaRowIconSpec(windowMinutes: windowMinutes)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.05))
                .overlay {
                    Circle()
                        .stroke(
                            Color.white.opacity(0.12),
                            lineWidth: spec.ringBorderWidth
                        )
                }

            switch spec.kind {
            case .clock:
                ClockGlyph(size: spec.clockSize, strokeWidth: spec.clockStrokeWidth)
                    .offset(y: spec.glyphVerticalOffset)
            case .calendar:
                Image(systemName: "calendar")
                    .font(.system(size: spec.calendarPointSize, weight: .regular))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: spec.calendarSize, height: spec.calendarSize)
                    .opacity(spec.calendarOpacity)
                    .offset(y: spec.glyphVerticalOffset)
            case .generic:
                Image(systemName: "questionmark")
                    .font(.system(size: spec.genericPointSize, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .frame(width: spec.ringSize, height: spec.ringSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(iconAccessibilityLabel)
    }

    private var iconAccessibilityLabel: String {
        switch spec.kind {
        case .clock: return "五小时额度"
        case .calendar: return "每周额度"
        case .generic: return "额度窗口"
        }
    }
}

private struct ClockGlyph: View {
    let size: CGFloat
    let strokeWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.primaryText, lineWidth: strokeWidth)

            Path { path in
                let center = CGPoint(x: size / 2, y: size / 2)
                let scale = size / 43.75
                path.move(to: center)
                path.addLine(to: CGPoint(x: center.x, y: center.y - 10.5 * scale))
                path.move(to: center)
                path.addLine(to: CGPoint(x: center.x + 10.5 * scale, y: center.y + 8.5 * scale))
            }
            .stroke(
                AppTheme.primaryText,
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}
