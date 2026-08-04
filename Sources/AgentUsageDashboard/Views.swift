import SwiftUI
import Charts

private enum PopoverSection: Hashable {
    case overview
    case provider(Provider)
    case settings
}

private enum AppTheme {
    static let background = Color(red: 0.043, green: 0.063, blue: 0.090)
    static let surface = Color(red: 0.075, green: 0.106, blue: 0.145)
    static let elevated = Color(red: 0.106, green: 0.149, blue: 0.200)
    static let primaryText = Color(red: 0.957, green: 0.969, blue: 0.984)
    static let secondaryText = Color(red: 0.604, green: 0.663, blue: 0.729)
    static let codex = Color(red: 0.424, green: 0.714, blue: 1.000)
    static let kimi = Color(red: 0.765, green: 0.608, blue: 1.000)
    static let success = Color(red: 0.306, green: 0.839, blue: 0.643)
    static let warning = Color(red: 0.961, green: 0.718, blue: 0.357)
}

private extension Provider {
    var iconName: String {
        switch self {
        case .codex: return "terminal.fill"
        case .kimiCode: return "moon.stars.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .codex: return AppTheme.codex
        case .kimiCode: return AppTheme.kimi
        }
    }
}

struct PopoverView: View {
    @ObservedObject var model: DashboardModel
    @Environment(\.openWindow) private var openWindow
    @State private var selectedSection: PopoverSection = .provider(.codex)

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeader(model: model)
            ProviderNavigationBar(model: model, selection: $selectedSection) { section in
                selectedSection = section
                if case let .provider(provider) = section {
                    model.selectProvider(provider)
                }
            }

            Divider().overlay(Color.white.opacity(0.10))

            ScrollView {
                selectedContent
            }
            .scrollIndicators(.hidden)

            Divider().overlay(Color.white.opacity(0.10))
            PopoverFooter(openWindow: openWindow)
        }
        .background(AppTheme.background)
        .frame(width: 420)
        .frame(minHeight: 560, maxHeight: 680)
        .preferredColorScheme(.dark)
        .onAppear {
            restoreSelection()
            normalizeSelection()
            model.refresh()
        }
        .onChange(of: model.navigation.visibleProviders) { _ in
            normalizeSelection()
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch normalizedSection {
        case .overview:
            OverviewPanel(model: model)
        case let .provider(provider):
            ProviderPanel(snapshot: model.snapshot(for: provider), openWindow: openWindow)
        case .settings:
            SettingsPanel(model: model)
        }
    }

    private var normalizedSection: PopoverSection {
        guard case let .provider(provider) = selectedSection else { return selectedSection }
        return model.navigation.isEnabled(provider) ? .provider(provider) : .overview
    }

    private func normalizeSelection() {
        guard case let .provider(provider) = selectedSection,
              !model.navigation.isEnabled(provider) else { return }
        selectedSection = model.navigation.visibleProviders.first.map(PopoverSection.provider) ?? .overview
    }

    private func restoreSelection() {
        guard let provider = model.navigation.selectedProvider,
              model.navigation.isEnabled(provider) else { return }
        selectedSection = .provider(provider)
    }
}

private struct PopoverHeader: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(AppTheme.codex.opacity(0.16))
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.codex)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Agent Meter")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                Text(model.lastRefresh.map { "更新于 \($0.formatted(date: .omitted, time: .shortened))" } ?? "等待首次采集")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Button {
                model.refresh()
            } label: {
                Image(systemName: model.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .rotationEffect(.degrees(model.isRefreshing ? 180 : 0))
            }
            .buttonStyle(.plain)
            .help("刷新账号数据")
            .disabled(model.isRefreshing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

private struct ProviderNavigationBar: View {
    @ObservedObject var model: DashboardModel
    @Binding var selection: PopoverSection
    let onSelect: (PopoverSection) -> Void

    var body: some View {
        HStack(spacing: 4) {
            NavigationTab(title: "概览", icon: "square.grid.2x2", isSelected: selection == .overview) {
                onSelect(.overview)
            }

            ForEach(model.navigation.visibleProviders, id: \.self) { provider in
                NavigationTab(
                    title: provider.displayName,
                    icon: provider.iconName,
                    tint: provider.accentColor,
                    isSelected: selection == .provider(provider)
                ) {
                    onSelect(.provider(provider))
                }
            }

            NavigationTab(title: "设置", icon: "gearshape", isSelected: selection == .settings) {
                onSelect(.settings)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

private struct NavigationTab: View {
    let title: String
    let icon: String
    var tint: Color = AppTheme.secondaryText
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                }
                .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? tint.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Capsule()
                    .fill(isSelected ? tint : .clear)
                    .frame(height: 2)
                    .padding(.horizontal, 7)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PopoverFooter: View {
    let openWindow: OpenWindowAction

    var body: some View {
        HStack(spacing: 10) {
            Button {
                openWindow(id: "details")
            } label: {
                Label("打开完整仪表盘", systemImage: "arrow.up.right.square")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.codex.opacity(0.72))

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.secondaryText)
            .help("退出")
        }
        .padding(16)
    }
}

private struct OverviewPanel: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("概览")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
            Text("选择上方服务查看完整额度与本机观测")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)

            if model.navigation.visibleProviders.isEmpty {
                EmptyNavigationState()
            } else {
                ForEach(model.navigation.visibleProviders, id: \.self) { provider in
                    OverviewProviderRow(snapshot: model.snapshot(for: provider))
                }
            }
        }
        .padding(18)
    }
}

private struct OverviewProviderRow: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        HStack(spacing: 12) {
            ProviderIconTile(provider: snapshot.provider, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.provider.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(snapshot.windows.first.map { "\($0.label) · 剩余 \($0.remainingPercent, specifier: "%.0f")%" } ?? "额度暂未获取")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            StatusBadge(status: snapshot.status, compact: true)
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08)))
    }
}

private struct ProviderPanel: View {
    let snapshot: ProviderSnapshot
    let openWindow: OpenWindowAction

    var body: some View {
        VStack(spacing: 16) {
            ProviderCard(snapshot: snapshot)
            if let error = snapshot.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.warning)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
    }
}

struct ProviderCard: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ProviderIconTile(provider: snapshot.provider, size: 66)

                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.provider.displayName)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                    StatusBadge(status: snapshot.status)
                }

                Spacer()

                Text(planLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(snapshot.provider.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(snapshot.provider.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            Divider().overlay(Color.white.opacity(0.10))

            if snapshot.windows.isEmpty {
                QuotaPlaceholder(provider: snapshot.provider)
            }
            else {
                ForEach(snapshot.windows) { window in
                    RateLimitRow(window: window, accent: snapshot.provider.accentColor)
                }
            }

            Divider().overlay(Color.white.opacity(0.10))

            HStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.success)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.success.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("本机观测")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("当前 Mac 的日志统计")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.secondaryText.opacity(0.78))
                }
                Spacer()
                Text("\(formatNumber(snapshot.localTokenUsage.total)) Token")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.primaryText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(18)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.10)))
    }

    private var planLabel: String {
        guard let plan = snapshot.account?.planType, !plan.isEmpty else { return "账号" }
        return plan.capitalized
    }
}

private struct ProviderIconTile: View {
    let provider: Provider
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(provider.accentColor.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous).stroke(provider.accentColor, lineWidth: 1.5))
            Image(systemName: provider.iconName)
                .font(.system(size: size * 0.33, weight: .semibold))
                .foregroundStyle(provider.accentColor)
        }
        .frame(width: size, height: size)
    }
}

private struct StatusBadge: View {
    let status: ProviderStatus
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: compact ? 6 : 8, height: compact ? 6 : 8)
            Text(status.displayText)
                .font(.system(size: compact ? 10 : 12, weight: .medium))
        }
        .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch status {
        case .connected: return AppTheme.success
        case .unavailable, .notAuthenticated, .notInstalled: return AppTheme.secondaryText
        case .error: return AppTheme.warning
        }
    }
}

struct RateLimitRow: View {
    let window: RateLimitWindow
    var accent: Color = AppTheme.codex

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(window.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Text("剩余 \(window.remainingPercent, specifier: "%.0f")%")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(accent)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(accent)
                            .frame(width: proxy.size.width * CGFloat(window.remainingPercent / 100))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("已用 \(window.usedPercent, specifier: "%.0f")%")
                    Spacer()
                    if let resetsAt = window.resetsAt {
                        Text(resetText(from: resetsAt, now: context.date))
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)
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

private struct QuotaPlaceholder: View {
    let provider: Provider

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(provider == .kimiCode ? "账号额度暂未接入" : "账号额度暂未获取")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
            Text(provider == .kimiCode ? "当前仅显示本机日志统计，不展示虚假百分比。" : "打开弹窗后会从 Codex App Server 刷新。")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

private struct SettingsPanel: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
            Text("选择要显示在顶部导航栏和概览中的 AI 服务")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)

            VStack(spacing: 0) {
                ForEach(Provider.allCases, id: \.self) { provider in
                    ProviderSettingRow(
                        provider: provider,
                        isEnabled: model.navigation.isEnabled(provider),
                        onChange: { enabled in
                            model.setProviderEnabled(provider, enabled: enabled)
                        }
                    )
                    if provider != Provider.allCases.last {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("关闭服务只会隐藏导航和卡片，不会删除已有历史数据。")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(18)
    }
}

private struct ProviderSettingRow: View {
    let provider: Provider
    let isEnabled: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ProviderIconTile(provider: provider, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(provider == .codex ? "账号额度与本机 Token" : "本机日志 Token")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isEnabled }, set: onChange))
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 13)
    }
}

private struct EmptyNavigationState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text("暂未启用 AI 服务")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text("前往设置打开 Codex 或 Kimi Code")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 45)
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
        model.navigation.visibleProviders.map { model.snapshot(for: $0) }
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
            ForEach(model.navigation.visibleProviders, id: \.self) { provider in
                Section("本机观测 · \(provider.displayName)") {
                    ModelRows(models: model.snapshot(for: provider).localModels)
                }
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
