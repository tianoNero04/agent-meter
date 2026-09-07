import SwiftUI

/// 统一控制台总窗口的核心业务分区枚举
enum MasterSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    // 偏好与系统分组
    case general = "general"
    case providers = "providers"
    case pricing = "pricing"
    case alerts = "alerts"

    // 洞察与对账分组
    case overview = "overview"
    case models = "models"
    case savings = "savings"

    var id: String { rawValue }

    /// 导航项标题
    var title: String {
        switch self {
        case .general: return "通用设置"
        case .providers: return "服务商与诊断"
        case .pricing: return "模型费率与成本"
        case .alerts: return "额度与重置提醒"
        case .overview: return "用量大盘总览"
        case .models: return "模型排行对账"
        case .savings: return "Prompt 缓存省钱"
        }
    }

    /// SF Symbol 图标名称
    var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .providers: return "network"
        case .pricing: return "dollarsign.circle"
        case .alerts: return "bell.badge"
        case .overview: return "gauge"
        case .models: return "chart.bar.xaxis"
        case .savings: return "bolt.shield"
        }
    }

    /// 所属的分组大类
    var group: SidebarGroup {
        switch self {
        case .general, .providers, .pricing, .alerts:
            return .preferences
        case .overview, .models, .savings:
            return .insights
        }
    }
}

/// 侧边栏分组类别
enum SidebarGroup: String, CaseIterable {
    case preferences = "PREFERENCES"
    case insights = "INSIGHTS"

    var title: String { rawValue }
}

/// 像素级复刻 ReactBits Pro (app-sidebar-1) 风格的现代深色固定侧边栏
struct AppSidebarView: View {
    @Binding var selection: MasterSection
    /// 诊断延迟徽标（例如 "38ms"）
    var latencyBadge: String?
    /// 模型数量徽标（例如 "2"）
    var modelCountBadge: String?

    init(
        selection: Binding<MasterSection>,
        latencyBadge: String? = nil,
        modelCountBadge: String? = nil
    ) {
        self._selection = selection
        self.latencyBadge = latencyBadge
        self.modelCountBadge = modelCountBadge
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部团队/刊头卡片（Header）
            sidebarHeader
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 16)

            // 分割发丝线
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 0.75)
                .padding(.horizontal, 12)

            // 中间分组导航列表
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(SidebarGroup.allCases, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 3) {
                            // 分组微标题（10pt 等宽加粗，全大写，带字距）
                            Text(group.title)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(AppTheme.tertiaryText)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 4)

                            // 组内导航项
                            ForEach(MasterSection.allCases.filter { $0.group == group }) { section in
                                SidebarNavItem(
                                    section: section,
                                    badge: badge(for: section),
                                    isSelected: selection == section
                                ) {
                                    selection = section
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 14)
            }

            Spacer(minLength: 10)

            // 底部运行守护卡片（Footer）
            sidebarFooter
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .frame(width: 220)
        .background(AppTheme.background)
        .overlay(alignment: .trailing) {
            // 侧边栏与工作区之间的 0.75pt 发丝基准线
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(width: 0.75)
        }
    }

    /// 顶部品牌刊头卡片
    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            // 品牌微圆角 Logo 徽标
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.hairlineBright, lineWidth: 0.75)
                    )

                AgentMeterLogo()
                    .frame(width: 18, height: 18)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("AGENT METER")
                    .font(.system(size: 12, weight: .heavy, design: .default))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.primaryText)

                Text("VOL.26 // LOCAL.DAEMON")
                    .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            Spacer(minLength: 0)
        }
    }

    /// 底部守护状态小卡片
    private var sidebarFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AppTheme.success)
                .frame(width: 6, height: 6)
                .shadow(color: AppTheme.success.opacity(0.5), radius: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text("Codex & Kimi Active")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)

                Text("macOS Native · v0.1.0")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.surface.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppTheme.hairline, lineWidth: 0.75)
                )
        )
    }

    /// 根据分区获取对应的徽标数据
    private func badge(for section: MasterSection) -> String? {
        switch section {
        case .providers: return latencyBadge
        case .models: return modelCountBadge
        default: return nil
        }
    }
}

/// 侧边栏导航条目：复刻 app-sidebar-1 悬停与选中质感
struct SidebarNavItem: View {
    let section: MasterSection
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: section.iconName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? AppTheme.primaryText : (isHovered ? AppTheme.primaryText : AppTheme.secondaryText))

                Text(section.title)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? AppTheme.primaryText : (isHovered ? AppTheme.primaryText : AppTheme.secondaryText))

                Spacer(minLength: 4)

                // 右侧数据徽标（如延迟、数量）
                if let badge, !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.tertiaryText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(isSelected ? 0.12 : 0.05))
                        )
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.white.opacity(0.08) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
