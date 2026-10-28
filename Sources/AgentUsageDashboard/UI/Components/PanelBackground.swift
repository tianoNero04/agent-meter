import SwiftUI

/// 瑞士网格模块容器修饰器：提供严谨紧凑的工业矩形底色与发丝级边框
struct PanelBackground: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.gridCornerRadius

    func body(content: Content) -> some View {
        content
            // 严谨深色表面底色
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

    }
}

extension View {
    func panelBackground(accent: Color = AppTheme.accent, cornerRadius: CGFloat = AppTheme.gridCornerRadius) -> some View {
        modifier(PanelBackground(cornerRadius: cornerRadius))
    }
}
