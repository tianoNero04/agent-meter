import SwiftUI

/// Compact provider menu with a softly illuminated leading edge.
struct ProviderNavigationBar: View {
    @ObservedObject var model: DashboardModel
    @Binding var selection: PopoverSection
    let onSelect: (Provider) -> Void
    @State private var isHovered = false

    private var selectedProvider: Provider? {
        guard case let .provider(provider) = selection,
              model.navigation.visibleProviders.contains(provider) else {
            return model.navigation.visibleProviders.first
        }
        return provider
    }

    var body: some View {
        Menu {
            ForEach(model.navigation.visibleProviders, id: \.self) { provider in
                Button {
                    onSelect(provider)
                } label: {
                    if provider == selectedProvider {
                        Label(provider.displayName, systemImage: "checkmark")
                    } else {
                        Text(provider.displayName)
                    }
                }
            }
        } label: {
            Text("").frame(width: 146, height: 36)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 146, height: 36)
        .overlay { selectorLabel.allowsHitTesting(false) }
        .disabled(model.navigation.visibleProviders.isEmpty)
        .onHover { isHovered = $0 }
        .accessibilityLabel("选择服务商")
        .accessibilityValue(selectedProvider?.displayName ?? "未启用服务商")
        .help("切换服务商")
    }

    private var selectorLabel: some View {
            HStack(spacing: 9) {
                icon
                Text(selectedProvider?.displayName ?? "服务商")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.trailing, 9)
            }
            .padding(.leading, 5)
            .frame(width: 146, height: 36)
            .background {
                Capsule()
                    .fill(AppTheme.heroBackground)
                    .overlay {
                        Capsule().fill(LinearGradient(
                            colors: [AppTheme.heroMint.opacity(isHovered ? 0.40 : 0.26), .clear],
                            startPoint: .leading, endPoint: UnitPoint(x: 0.48, y: 0.5)
                        ))
                    }
                    .overlay {
                        Capsule().strokeBorder(LinearGradient(
                            colors: [AppTheme.heroMint.opacity(0.9), AppTheme.heroMint.opacity(0.13), AppTheme.heroMint.opacity(0.28)],
                            startPoint: .leading, endPoint: .trailing
                        ), lineWidth: 0.75)
                    }
                    .allowsHitTesting(false)
            }
            .contentShape(Capsule())
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.heroBackground)
            if let provider = selectedProvider {
                if let image = BundleImages.providerIcon(for: provider) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(3)
                } else {
                    Image(systemName: provider.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppTheme.heroMint.opacity(0.22), lineWidth: 0.75)
        }
        .accessibilityHidden(true)
    }
}

