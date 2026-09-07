import SwiftUI
import ServiceManagement

/// 通用系统偏好配置面板
struct GeneralSettingsTab: View {
    @ObservedObject var model: DashboardModel
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)

    init(model: DashboardModel) {
        self.model = model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // 顶栏刊头标示
            tabHeader(
                title: "通用系统设置",
                subtitle: "PREFERENCES // GENERAL.SYSTEM",
                icon: "gearshape"
            )

            // 开机启动卡片
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("开机自动启动")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("在 macOS 系统开机登录时静默启动 Agent Meter 菜单栏小工具")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()

                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { enable in
                            updateLaunchAtLogin(enabled: enable)
                        }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                            .stroke(AppTheme.hairline, lineWidth: 0.75)
                    )
            )

            // 菜单栏常驻策略说明卡片
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "menubar.rectangle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.codex)

                    Text("系统状态栏极简纯净原则")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }

                Text("Agent Meter 遵循克制、无打扰的瑞士设计原则。macOS 顶部状态栏仅保留高清晰度极简几何图标，不常驻数字或跳动字符；当点击右上角面板按钮启动控制中心总窗口时，将即刻动态唤起 Dock 栏图标并激活前台。")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                    .fill(AppTheme.surface.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                            .stroke(AppTheme.hairline, lineWidth: 0.75)
                    )
            )

            Spacer()
        }
        .padding(.top, 44)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    /// 更新开机自启动配置
    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("更新开机启动失败：\(error)")
        }
    }

    /// 通用标题栏样式
    func tabHeader(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.codex)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            Spacer()
        }
    }
}
