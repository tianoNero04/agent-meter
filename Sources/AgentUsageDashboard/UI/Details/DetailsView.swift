import SwiftUI

struct DetailsView: View {
    @ObservedObject var model: DashboardModel
    var body: some View {
        TabView {
            OverviewTab(model: model).tabItem { Label("概览", systemImage: "gauge") }
            ModelUsageTab(model: model).tabItem { Label("模型", systemImage: "chart.bar.xaxis") }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            // 打开详细统计窗口时动态保持 Dock 栏图标展示
            DockPolicyManager.shared.windowDidAppear("details")
        }
        .onDisappear {
            // 关闭详细统计窗口时通知管理器重新评估
            DockPolicyManager.shared.windowDidDisappear("details")
        }
    }
}
