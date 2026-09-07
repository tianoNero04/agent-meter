import SwiftUI

/// 用量总览标签页：对接 MonitoringDashboardView 提供 ReactBits monitoring-8 风格监控大盘
struct OverviewTab: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        MonitoringDashboardView(model: model)
    }
}

