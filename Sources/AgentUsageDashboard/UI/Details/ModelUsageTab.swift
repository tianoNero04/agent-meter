import SwiftUI

struct ModelUsageTab: View {
    @ObservedObject var model: DashboardModel
    var body: some View {
        List {
            ForEach(model.navigation.visibleProviders, id: \.self) { provider in
                Section("本机观测 · \(provider.displayName)") { ModelRows(models: model.snapshot(for: provider).localModels) }
            }
            Section { Text("模型 Token 明细目前是本机日志观测值，不代表账号全量。账号级接口当前只提供总量和每日汇总。").font(.caption).foregroundStyle(.secondary) }
        }
        .listStyle(.inset)
    }
}

struct ModelRows: View {
    let models: [ModelUsage]
    var body: some View {
        if models.isEmpty {
            Text("暂无数据").foregroundStyle(.secondary)
        } else {
            ForEach(models) { item in
                HStack { Text(item.model).font(.body.monospaced()); Spacer(); Text(formatNumber(item.usage.total)).font(.body.monospacedDigit()) }
            }
        }
    }
}
