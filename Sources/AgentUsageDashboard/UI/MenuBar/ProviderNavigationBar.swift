import SwiftUI

struct ProviderNavigationBar: View {
    @ObservedObject var model: DashboardModel
    @Binding var selection: PopoverSection
    let onSelect: (Provider) -> Void
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(model.navigation.visibleProviders, id: \.self) { provider in
                NavigationTab(
                    title: provider.displayName.uppercased(),
                    isSelected: selection == .provider(provider),
                    namespace: tabNamespace
                ) {
                    onSelect(provider)
                }
            }
            Text("...")
                .font(.system(size: 11, weight: .regular, design: .default))
                .tracking(0.5)
                .foregroundStyle(AppTheme.secondaryText.opacity(0.6))
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
        }
        .animation(.easeInOut(duration: 0.22), value: selection)
    }
}

struct NavigationTab: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .regular, design: .default))
                .tracking(0.5)
                .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
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

/// 选中态玻璃 chip：半透明填充 + 上亮下暗描边 + 底部蓝色发光下划线（白芯蓝晕，收在 chip 内底边上方）。
struct SelectedTabChip: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.42), Color.white.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(Color.white.opacity(0.95))
                    .frame(height: 2)
                    .padding(.horizontal, 14)
                    .shadow(color: AppTheme.codex.opacity(0.95), radius: 6)
                    .shadow(color: AppTheme.codex.opacity(0.6), radius: 2)
                    .offset(y: -1.5)
            }
    }
}
