import SwiftUI

struct PanelBackground: ViewModifier {
    let accent: Color
    func body(content: Content) -> some View {
        content
            .background(.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(accent.opacity(0.34), lineWidth: 1))
    }
}

extension View {
    func panelBackground(accent: Color) -> some View { modifier(PanelBackground(accent: accent)) }
}
