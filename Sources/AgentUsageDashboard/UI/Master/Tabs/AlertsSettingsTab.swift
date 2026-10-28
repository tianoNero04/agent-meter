import SwiftUI

/// 通知调度尚未实现，明确展示可用性，避免把界面开关误认为生效状态。
struct AlertsSettingsTab: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                Text("额度与重置提醒")
                    .font(.system(size: 18, weight: .semibold))

                VStack(alignment: .leading, spacing: 12) {
                    Label("额度提醒暂不可用", systemImage: "bell.slash")
                        .font(.system(size: 14, weight: .semibold))
                    Text("当前版本尚未接入通知调度，不会发送额度重置或低额度提醒。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Text("请在菜单栏弹窗查看剩余额度和重置时间。通知权限本身不代表提醒已经生效。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .panelBackground()
            }
            .foregroundStyle(AppTheme.primaryText)
            .padding(24)
        }
    }
}
