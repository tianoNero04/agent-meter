import SwiftUI

struct ProviderNavigationBar: View {
    @ObservedObject var model: DashboardModel
    @Binding var selection: PopoverSection
    let onSelect: (Provider) -> Void
    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(model.navigation.visibleProviders, id: \.self) { provider in
                ProviderIconTab(
                    provider: provider,
                    isSelected: selection == .provider(provider),
                    namespace: tabNamespace
                ) {
                    onSelect(provider)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: selection)
    }
}

struct ProviderIconTab: View {
    let provider: Provider
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false
    private let tabSize: CGFloat = 30

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.13) : Color.white.opacity(isHovered ? 0.09 : 0.035))
                if let icon = BundleImages.providerIcon(for: provider) {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .opacity(isSelected ? 1.0 : (isHovered ? 0.92 : 0.68))
                } else {
                    Image(systemName: provider.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                        .opacity(isSelected ? 1.0 : (isHovered ? 0.92 : 0.68))
                }
                if isSelected {
                    SelectedTabChip()
                        .matchedGeometryEffect(id: "selectedTab", in: namespace)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 0.75)
                }
            }
            .frame(width: tabSize, height: tabSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(provider.displayName)
        .accessibilityLabel(provider.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SelectedTabChip: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(AppTheme.accent.opacity(0.72), lineWidth: 1)
    }
}

