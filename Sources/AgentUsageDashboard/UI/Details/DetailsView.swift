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
    }
}
