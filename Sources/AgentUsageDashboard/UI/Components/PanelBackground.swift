import SwiftUI

/// 瑞士网格模块容器修饰器：提供严谨紧凑的工业矩形底色与发丝级边框
struct PanelBackground: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.gridCornerRadius

    func body(content: Content) -> some View {
        content
            // 严谨深色表面底色
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // 极细发丝级边界线（0.75pt 呈现高精度工业印刷感）
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 0.75)
            )
    }
}

extension View {
    func panelBackground(accent: Color = AppTheme.codex, cornerRadius: CGFloat = AppTheme.gridCornerRadius) -> some View {
        modifier(PanelBackground(cornerRadius: cornerRadius))
    }
}
