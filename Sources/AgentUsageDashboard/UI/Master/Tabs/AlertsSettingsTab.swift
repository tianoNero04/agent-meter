import SwiftUI
import UserNotifications

/// 额度预警与满血复活通知设置面板
struct AlertsSettingsTab: View {
    @ObservedObject var model: DashboardModel
    @State private var enableResetAlert = true
    @State private var enableLowQuotaAlert = true
    @State private var lowQuotaThreshold = 10
    @State private var notificationStatusText = "检查中..."

    init(model: DashboardModel) {
        self.model = model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // 顶栏刊头标示
            HStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.codex)

                VStack(alignment: .leading, spacing: 1) {
                    Text("额度预警与重置通知")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("ALERTS // ZERO.OVERHEAD.NOTIFICATIONS")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                Spacer()
            }

            // 核心功能卡片 1：“满血复活”重置闹钟
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("“满血复活”额度重置提醒")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)

                            Text("0 额外网络开销")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.success)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppTheme.success.opacity(0.12))
                                )
                        }

                        Text("当 5 小时额度或周额度重置完成时，由 macOS 系统内核直接弹出通知提醒继续开工。")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()

                    Toggle("", isOn: $enableResetAlert)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Rectangle().fill(AppTheme.hairline).frame(height: 0.75)

                Text("技术原理：完全无需后台轮询发 HTTP 包。应用直接利用最近一次查额度已获取的精确 resets_at 时间戳，交由 macOS 原生 UNCalendarNotificationTrigger 调度，CPU 占用与网络请求均为 0。")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineSpacing(3)
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

            // 核心功能卡片 2：额度低阈值告警
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("5 小时额度防猝死预警")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("当 5 小时可用额度低于设定阈值时发出系统提醒，避免写代码正爽突然被掐断。")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()

                    Toggle("", isOn: $enableLowQuotaAlert)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if enableLowQuotaAlert {
                    HStack(spacing: 12) {
                        Text("预警阈值：低于")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)

                        Picker("", selection: $lowQuotaThreshold) {
                            Text("15%").tag(15)
                            Text("10%").tag(10)
                            Text("5%").tag(5)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    .padding(.top, 4)
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

            // 系统通知权限检测条
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.tertiaryText)

                Text("系统通知权限状态: \(notificationStatusText)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)

                Spacer()

                Button("请求系统授权") {
                    requestNotificationAuth()
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.link)
            }
            .padding(.horizontal, 4)

            Spacer()
        }
        .padding(.top, 44)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onAppear {
            checkNotificationStatus()
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    notificationStatusText = "已授权 ✓"
                case .denied:
                    notificationStatusText = "已禁用（请在 macOS 系统设置中开启）"
                default:
                    notificationStatusText = "待授权"
                }
            }
        }
    }

    private func requestNotificationAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationStatusText = granted ? "已授权 ✓" : "用户拒绝"
            }
        }
    }
}
