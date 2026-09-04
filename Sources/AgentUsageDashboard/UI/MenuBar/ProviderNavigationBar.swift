import SwiftUI

/// 瑞士风格 Provider 网格导航栏组件：呈现清晰、高对比度的出版物选项卡
struct ProviderNavigationBar: View {
    @ObservedObject var model: DashboardModel
    @Binding var selection: PopoverSection
    let onSelect: (Provider) -> Void
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(model.navigation.visibleProviders, id: \.self) { provider in
                NavigationTab(
                    title: provider.displayName.uppercased(),
                    isSelected: selection == .provider(provider),
                    namespace: tabNamespace
                ) {
                    onSelect(provider)
                }
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.20), value: selection)
    }
}

/// 粗野主义网格单项标签：高电压柠檬黄激活底色与纯黑硬边框
struct NavigationTab: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .black : .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4.5)
                .background {
                    if isSelected {
                        SelectedTabChip()
                            .matchedGeometryEffect(id: "selectedTab", in: namespace)
                    } else {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(AppTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(AppTheme.border.opacity(0.35), lineWidth: 1.0)
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// 选中态粗野主义指示框：高亮柠檬黄底色 + 1.25pt 纯黑边框 + 1.5pt 硬阴影
struct SelectedTabChip: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(AppTheme.lemonYellow)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1.25)
            )
            .shadow(color: Color.black.opacity(0.85), radius: 0, x: 1.5, y: 1.5)
    }
}
