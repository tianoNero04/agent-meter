import SwiftUI
import AppKit

struct PanelBackground: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.gridCornerRadius

    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct PopoverMaterialBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

extension View {
    func panelBackground(accent: Color = AppTheme.accent, cornerRadius: CGFloat = AppTheme.gridCornerRadius) -> some View {
        modifier(PanelBackground(cornerRadius: cornerRadius))
    }

    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
            )
    }
}
