import SwiftUI
import Charts

struct PopoverView: View {
    @ObservedObject var model: DashboardModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Usage")
                        .font(.headline)
                    Text(model.lastRefresh.map { "更新于 \($0.formatted(date: .omitted, time: .shortened))" } ?? "等待首次采集")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.refresh()
                } label: {
                    Image(systemName: model.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("刷新账号数据")
                .disabled(model.isRefreshing)
            }

            ProviderCard(snapshot: model.codex)
            ProviderCard(snapshot: model.kimi)

            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }

            Divider()

            HStack {
                Button("查看详细统计") { openWindow(id: "details") }
                    .buttonStyle(.link)
                Spacer()
                Button("退出") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.link)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            model.refresh()
        }
    }
}

struct ProviderCard: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: snapshot.provider == .codex ? "terminal" : "moon.stars")
                    .foregroundStyle(snapshot.provider == .codex ? .blue : .purple)
                Text(snapshot.provider.displayName).font(.headline)
                Spacer()
                Text(snapshot.status.displayText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            if let account = snapshot.account {
                Text([account.planType, account.email].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if snapshot.windows.isEmpty {
                Text(snapshot.provider == .kimiCode ? "账号额度：平台适配器待接入" : "账号额度：暂未获取")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.windows) { window in
                    RateLimitRow(window: window)
                }
            }

            HStack {
                Metric(label: "账号 Token", value: snapshot.accountUsage?.lifetimeTokens.map(formatNumber) ?? "未提供")
                Divider().frame(height: 28)
                Metric(label: "本机观测", value: formatNumber(snapshot.localTokenUsage.total))
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        switch snapshot.status {
        case .connected: return .green
        case .unavailable, .notAuthenticated, .notInstalled: return .secondary
        case .error: return .orange
        }
    }
}

struct RateLimitRow: View {
    let window: RateLimitWindow

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 8) {
                Text(window.label)
                    .font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("剩余 \(window.remainingPercent, specifier: "%.0f")%")
                        .font(.subheadline.weight(.semibold))
                    if let resetsAt = window.resetsAt {
                        Text(resetText(from: resetsAt, now: context.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func resetText(from date: Date, now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds == 0 { return "即将重置" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "约 \(hours) 小时 \(minutes) 分钟后重置" }
        return "约 \(max(1, minutes)) 分钟后重置"
    }
}

struct Metric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailsView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        TabView {
            OverviewTab(model: model)
                .tabItem { Label("概览", systemImage: "gauge") }
            ModelUsageTab(model: model)
                .tabItem { Label("模型", systemImage: "chart.bar.xaxis") }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 520)
    }
}

struct OverviewTab: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("账号额度与 Token 趋势")
                    .font(.title2.weight(.semibold))
                ForEach(snapshots, id: \.provider) { snapshot in
                    ProviderTrendCard(snapshot: snapshot)
                }
            }
        }
    }

    private var snapshots: [ProviderSnapshot] {
        [model.codex, model.kimi]
    }
}

struct ProviderTrendCard: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(snapshot.provider.displayName).font(.headline)
            if let usage = snapshot.accountUsage, let buckets = usage.dailyBuckets, !buckets.isEmpty {
                Chart(buckets) { bucket in
                    BarMark(
                        x: .value("日期", bucket.startDate, unit: .day),
                        y: .value("Token", bucket.tokens)
                    )
                    .foregroundStyle(snapshot.provider == .codex ? Color.blue : Color.purple)
                }
                .frame(height: 180)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("暂无账号趋势")
                        .foregroundStyle(.secondary)
                    Text("平台未提供或尚未完成采集")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ModelUsageTab: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        List {
            Section("本机观测 · Codex") {
                ModelRows(models: model.codex.localModels)
            }
            Section("本机观测 · Kimi Code") {
                ModelRows(models: model.kimi.localModels)
            }
            Section {
                Text("模型 Token 明细目前是本机日志观测值，不代表账号全量。账号级接口当前只提供总量和每日汇总。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                HStack {
                    Text(item.model).font(.body.monospaced())
                    Spacer()
                    Text(formatNumber(item.usage.total)).font(.body.monospacedDigit())
                }
            }
        }
    }
}

func formatNumber(_ value: Int) -> String {
    value.formatted(.number.grouping(.automatic))
}
