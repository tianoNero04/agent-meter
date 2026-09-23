import SwiftUI

/// 瑞士风格 Provider 图标导航栏组件：以紧凑高质感的微缩图标呈现提供者切换
struct ProviderNavigationBar: View {
    @ObservedObject var model: DashboardModel
    @Binding var selection: PopoverSection
    let onSelect: (Provider) -> Void
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 5) {
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
        .animation(.easeInOut(duration: 0.20), value: selection)
    }
}

/// 单项微缩图标切换按钮
struct ProviderIconTab: View {
    let provider: Provider
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false

    // 严谨等宽等高的 24x24 几何微方块
    private let tabSize: CGFloat = 24

    var body: some View {
        Button(action: action) {
            ZStack {
                // Provider 专属高清图标或暗黑方块底衬
                if let icon = BundleImages.providerIcon(for: provider) {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: tabSize, height: tabSize)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous))
                        .opacity(isSelected ? 1.0 : (isHovered ? 0.9 : 0.6))
                } else {
                    // 与位图图标统一形态的暗黑方块底衬
                    RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                        .fill(AppTheme.elevated)
                        .frame(width: tabSize, height: tabSize)

                    Image(systemName: provider.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                        .opacity(isSelected ? 1.0 : (isHovered ? 0.9 : 0.6))
                }

                // 选中态高能荧光绿边框高光
                if isSelected {
                    SelectedTabChip()
                        .matchedGeometryEffect(id: "selectedTab", in: namespace)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                        .stroke(AppTheme.hairlineBright, lineWidth: 0.75)
                }
            }
            .frame(width: tabSize, height: tabSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(provider.displayName)
    }
}

/// 选中态平面构成主义指示框：与方块图标完全等大的荧光绿发丝反光边框
struct SelectedTabChip: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
            .stroke(AppTheme.neonGreenBorder, lineWidth: 1.0)
            .shadow(color: AppTheme.neonGreen.opacity(0.35), radius: 1.5)
    }
}

