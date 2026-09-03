import SwiftUI

/// 刷新图标：圆弧线 + V 形箭头，按选定图标的样式纯代码绘制。
/// 比例换算自 1024×1024 参考图：圆心 (0.488, 0.539)，弧半径 0.2707，线宽 0.094，右上角缺口。
struct RefreshIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.minX + 0.488 * side, y: rect.minY + 0.539 * side)
        func polar(_ radius: CGFloat, _ degrees: CGFloat) -> CGPoint {
            let angle = degrees * .pi / 180
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }

        // 圆弧：从 -10° 顺时针扫 290° 到 -80°（右上角留 70° 缺口），折线逼近 + 圆头线帽。
        // 缺口和箭头间隙按 18pt 实际尺寸校准，保证缩小后仍有可见间隙。
        let radius = 0.2707 * side
        var arc = Path()
        let segmentCount = 64
        for index in 0...segmentCount {
            let degrees = -10 + 290 * Double(index) / Double(segmentCount)
            let point = polar(radius, degrees)
            if index == 0 {
                arc.move(to: point)
            } else {
                arc.addLine(to: point)
            }
        }
        var path = arc.strokedPath(StrokeStyle(lineWidth: 0.094 * side, lineCap: .round, lineJoin: .round))

        // 箭头：缺口中的 V 形圆头短线，指向顺时针方向，与弧的两端都保持明显间隙。
        let arcEnd = polar(radius, -80)
        let tangent = CGVector(dx: 0.985, dy: 0.174)  // -80° 处顺时针切线方向
        let normal = CGVector(dx: 0.174, dy: -0.985)  // 外法线方向
        func arrowPoint(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
            CGPoint(
                x: arcEnd.x + (along * tangent.dx + across * normal.dx) * side,
                y: arcEnd.y + (along * tangent.dy + across * normal.dy) * side
            )
        }
        var arrow = Path()
        arrow.move(to: arrowPoint(0.12, 0.11))
        arrow.addLine(to: arrowPoint(0.26, 0.0))
        arrow.addLine(to: arrowPoint(0.12, -0.11))
        path.addPath(arrow.strokedPath(StrokeStyle(lineWidth: 0.08 * side, lineCap: .round, lineJoin: .round)))
        return path
    }
}
