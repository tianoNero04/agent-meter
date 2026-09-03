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

/// 瑞士网格单项标签
struct NavigationTab: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.5, weight: isSelected ? .bold : .medium, design: .default))
                .tracking(0.6)
                .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 5.5)
                .background {
                    if isSelected {
                        SelectedTabChip()
                            .matchedGeometryEffect(id: "selectedTab", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// 选中态瑞士指示框：硬朗微圆角 + 纯正深色垫底 + 底部高反差国际蓝基准标尺线
struct SelectedTabChip: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(AppTheme.elevated)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(AppTheme.hairlineBright, lineWidth: 0.75)
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.codex)
                    .frame(height: 2)
                    .padding(.horizontal, 6)
            }
    }
}
