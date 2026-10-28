import SwiftUI
import ServiceManagement

/// 通用系统偏好配置面板
struct GeneralSettingsTab: View {
    @ObservedObject var model: DashboardModel
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    @State private var launchAtLoginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                Text("通用设置")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("开机自动启动")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("登录 macOS 后在菜单栏启动 Agent Meter")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel("开机自动启动")
                        .onChange(of: launchAtLogin) { enabled in
                            updateLaunchAtLogin(enabled: enabled)
                        }
                }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
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

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "menubar.rectangle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                    Text("菜单栏与控制中心")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                Text("菜单栏仅显示应用图标。打开控制中心时，Agent Meter 会激活窗口并显示 Dock 图标；关闭控制中心后恢复菜单栏模式。")
                    .font(.system(size: 11))
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
        .padding(24)
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            launchAtLoginError = nil
        }
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            launchAtLoginError = "无法更新开机启动：\(error.localizedDescription)"
        }
    }
}
