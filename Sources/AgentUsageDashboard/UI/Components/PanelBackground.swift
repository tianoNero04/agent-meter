import SwiftUI

/// 粗野主义（Neo-Brutalism）卡片容器修饰器：纯白卡片、1.25pt 纯黑实线外框与 2pt 硬位移硬阴影
struct PanelBackground: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.gridCornerRadius

    func body(content: Content) -> some View {
        content
            // 纯白工业卡片底色
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // 粗野主义 1.25pt 纯黑边框
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1.25)
            )
            // 粗野主义标志性 2pt 零模糊纯黑硬阴影（Hard Offset Shadow）
            .shadow(color: Color.black.opacity(0.85), radius: 0, x: 2, y: 2)
    }
}

extension View {
    func panelBackground(accent: Color = AppTheme.codex, cornerRadius: CGFloat = AppTheme.gridCornerRadius) -> some View {
        modifier(PanelBackground(cornerRadius: cornerRadius))
    }
}
