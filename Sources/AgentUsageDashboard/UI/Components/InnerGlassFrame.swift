import SwiftUI

/// 双层玻璃的第二层内框：贴在烘焙玻璃壳内侧，随内容层一起滑动。
/// 烘焙外壳圆角约 10pt，内框按 inset 取同心圆角（10 - inset），角才能和外壳平行。
/// dimmed 用于 hero 卡：更淡、轻微模糊，像融进背景贴图里；verticalShift 可微调上下位置。
struct InnerGlassFrame: ViewModifier {
    var inset: CGFloat = 5
    var verticalShift: CGFloat = 0
    var dimmed: Bool = false

    private var cornerRadius: CGFloat { max(4, 10 - inset) }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(dimmed ? 0.015 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(dimmed ? 0.16 : 0.34),
                                        Color.white.opacity(dimmed ? 0.05 : 0.10)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(EdgeInsets(
                        top: inset + verticalShift,
                        leading: inset,
                        bottom: inset - verticalShift,
                        trailing: inset
                    ))
                    .blur(radius: dimmed ? 1.2 : 0)
            )
    }
}

extension View {
    func innerGlassFrame(verticalShift: CGFloat = 0, dimmed: Bool = false) -> some View {
        modifier(InnerGlassFrame(verticalShift: verticalShift, dimmed: dimmed))
    }
}
