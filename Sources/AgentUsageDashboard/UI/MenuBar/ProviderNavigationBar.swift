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

    var body: some View {
        Button(action: action) {
            ZStack {
                // 选中态背景底衬与蓝色基准线
                if isSelected {
                    SelectedTabChip()
                        .matchedGeometryEffect(id: "selectedTab", in: namespace)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.surface.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(AppTheme.hairline.opacity(0.6), lineWidth: 0.75)
                        )
                }

                // Provider 专属高清图标
                if let icon = BundleImages.providerIcon(for: provider) {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .opacity(isSelected ? 1.0 : (isHovered ? 0.9 : 0.55))
                } else {
                    Image(systemName: provider.iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                        .opacity(isSelected ? 1.0 : (isHovered ? 0.9 : 0.55))
                }
            }
            .frame(width: 26, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(provider.displayName)
    }
}

/// 选中态平面构成主义指示框：纯黑硬朗微方块 + 荧光绿微细反光边框 + 右下角高能荧光绿发光微指示点
struct SelectedTabChip: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
            .fill(AppTheme.elevated)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                    .stroke(AppTheme.neonGreenBorder, lineWidth: 0.75)
            )
            .overlay(alignment: .bottomTrailing) {
                // 标志性右下角荧光绿微型发光指示点
                Circle()
                    .fill(AppTheme.neonGreen)
                    .frame(width: 3.5, height: 3.5)
                    .shadow(color: AppTheme.neonGreen.opacity(0.9), radius: 2)
                    .offset(x: -2.5, y: -2.5)
            }
    }
}

