import SwiftUI
import Charts

enum QuotaPagination {
    static func pages(for windows: [RateLimitWindow]) -> [[RateLimitWindow]] {
        stride(from: 0, to: windows.count, by: 2).map {
            Array(windows[$0..<min($0 + 2, windows.count)])
        }
    }
}

struct ProviderPanel: View {
    let snapshot: ProviderSnapshot
    let isRefreshing: Bool
    let lastRefresh: Date?
    let refresh: () -> Void
    var slideEdge: Edge = .trailing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var removalEdge: Edge { slideEdge == .trailing ? .leading : .trailing }

    var body: some View {
        VStack(spacing: 10) {
            ProviderHeroCard(snapshot: snapshot)
            QuotaCard(
                snapshot: snapshot,
                isRefreshing: isRefreshing,
                lastRefresh: lastRefresh,
                refresh: refresh
            )
            TokenUsageCard(snapshot: snapshot)
        }
        .id(snapshot.provider)
        .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: slideEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        ))
    }
}

struct ProviderHeroCard: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        HStack(spacing: 12) {
            ProviderIconTile(provider: snapshot.provider, size: 46, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.provider.displayName.uppercased())
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.primaryText)
                Text(heroDetail)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(snapshot.errorMessage == nil ? AppTheme.secondaryText : AppTheme.warning)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(heroDetail)
            .accessibilityLabel(heroDetail)

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
                Text(planLabel)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(snapshot.account == nil ? AppTheme.secondaryText : AppTheme.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: 108, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.055), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.75))
            .help(planLabel)
        }
        .padding(.horizontal, 14)
        .frame(height: 78)
        .glassBackground()
    }

    private var heroDetail: String {
        if let error = snapshot.errorMessage { return "账号刷新失败 · \(error)" }
        if let email = snapshot.account?.email, !email.isEmpty { return email }
        return accountSubtitle
    }

    private var accountSubtitle: String {
        switch snapshot.provider {
        case .codex: return "OpenAI · 尚未获取账号"
        case .kimiCode: return "Moonshot AI · 尚未获取账号"
        case .antigravity: return "Google · 尚未获取账号"
        case .claude: return "Anthropic · 尚未获取账号"
        default: return "尚未获取账号"
        }
    }

    private var planLabel: String {
        guard let plan = snapshot.account?.planType, !plan.isEmpty else { return "未获取" }
        return plan.uppercased()
    }

    private var statusColor: Color {
        if snapshot.errorMessage != nil { return AppTheme.warning }
        return snapshot.account == nil ? AppTheme.tertiaryText : AppTheme.accent
    }
}

private struct PressBounceButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.92 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct QuotaCard: View {
    let snapshot: ProviderSnapshot
    let isRefreshing: Bool
    let lastRefresh: Date?
    let refresh: () -> Void
    @State private var currentPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pages: [[RateLimitWindow]] { QuotaPagination.pages(for: snapshot.windows) }
    private var visibleWindows: [RateLimitWindow] {
        guard !pages.isEmpty else { return [] }
        return pages[min(currentPage, pages.count - 1)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text("剩余额度")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer(minLength: 4)

                if pages.count > 1 {
                    pageControls
                } else if let lastRefresh {
                    Text(lastRefresh.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                        .help("最近刷新：\(lastRefresh.formatted())")
                }

                Button(action: refresh) {
                    HStack(spacing: 5) {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.mini)
                                .frame(width: 10, height: 10)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text(isRefreshing ? "查询中" : "刷新")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(AppTheme.accent.opacity(0.09), in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.accent.opacity(0.25), lineWidth: 0.75))
                }
                .buttonStyle(PressBounceButtonStyle(reduceMotion: reduceMotion))
                .disabled(isRefreshing)
                .opacity(isRefreshing ? 0.65 : 1)
                .help("刷新账号额度")
                .accessibilityLabel(isRefreshing ? "正在刷新账号额度" : "刷新账号额度")
            }
            .padding(.horizontal, 14)
            .frame(height: 40)

            if snapshot.windows.isEmpty {
                QuotaEmptyState(snapshot: snapshot)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 5) {
                    ForEach(visibleWindows) { window in
                        RateLimitRow(window: window)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(height: 168, alignment: .top)
        .glassBackground()
        .onChange(of: snapshot.provider) { _ in currentPage = 0 }
        .onChange(of: snapshot.windows.count) { _ in
            currentPage = min(currentPage, max(0, pages.count - 1))
        }
    }

    private var pageControls: some View {
        HStack(spacing: 2) {
            Button { currentPage = max(0, currentPage - 1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 20, height: 20)
            }
            .disabled(currentPage == 0)
            .accessibilityLabel("上一页额度")
            Text("\(min(currentPage + 1, pages.count))/\(pages.count)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityLabel("额度第 \(min(currentPage + 1, pages.count)) 页，共 \(pages.count) 页")
            Button { currentPage = min(pages.count - 1, currentPage + 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 20, height: 20)
            }
            .disabled(currentPage >= pages.count - 1)
            .accessibilityLabel("下一页额度")
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.secondaryText)
    }
}

struct TokenUsageCard: View {
    let snapshot: ProviderSnapshot

    private var buckets: [DailyTokenBucket] {
        recentSevenDayBuckets(snapshot.localDailyBuckets)
    }

    private var chartSummary: String {
        guard let peak = buckets.max(by: { $0.tokens < $1.tokens }) else { return "近 7 日暂无本机用量" }
        let day = peak.startDate.formatted(.dateTime.month().day())
        return "近 7 日本机 Token 趋势，\(day) 最高，\(peak.tokens) Token"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("本机 Token")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("近 7 日")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(formatCompactNumber(snapshot.localTokenUsage.total))
                        .font(.system(size: 25, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .accessibilityLabel("本机累计 \(snapshot.localTokenUsage.total) Token")
                    if snapshot.localTokenUsage.cachedInput > 0 {
                        HStack(spacing: 4) {
                            Text("缓存")
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("\(Int(round(snapshot.localTokenUsage.cacheHitRate * 100)))%")
                                .foregroundStyle(AppTheme.accent)
                        }
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.accent.opacity(0.08), in: Capsule())
                    } else if snapshot.localTokenUsage.input > 0 || snapshot.localTokenUsage.output > 0 {
                        HStack(spacing: 3) {
                            Text("IN \(formatCompactNumber(snapshot.localTokenUsage.input))")
                            Text("·")
                            Text("OUT \(formatCompactNumber(snapshot.localTokenUsage.output))")
                        }
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                    }
                }
                .frame(width: 140, alignment: .leading)

                if buckets.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.tertiaryText)
                        Text("暂无本机趋势")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                } else {
                    Chart(buckets) { bucket in
                        LineMark(x: .value("日期", bucket.startDate, unit: .day), y: .value("Token", bucket.tokens))
                            .foregroundStyle(AppTheme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("日期", bucket.startDate, unit: .day), y: .value("Token", bucket.tokens))
                            .foregroundStyle(AppTheme.primaryText)
                            .symbolSize(16)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .accessibilityLabel(chartSummary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(height: 104)
        .glassBackground()
    }
}

struct QuotaEmptyState: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("账号额度")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(statusTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(snapshot.errorMessage == nil ? AppTheme.secondaryText : AppTheme.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.055), in: Capsule())
            }
            Capsule()
                .fill(Color.white.opacity(0.07))
                .frame(height: 6)
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(snapshot.errorMessage == nil ? AppTheme.secondaryText : AppTheme.warning)
                .lineLimit(2)
                .help(description)
                .accessibilityLabel(description)
        }
    }

    private var statusTitle: String {
        if snapshot.errorMessage != nil { return "账号查询未完成" }
        return snapshot.account == nil ? "尚未获取账号额度" : "接口未返回额度"
    }

    private var statusLabel: String {
        if snapshot.errorMessage != nil { return "失败" }
        return snapshot.account == nil ? "待获取" : "无记录"
    }

    private var description: String {
        if let error = snapshot.errorMessage { return error }
        if snapshot.account != nil { return "账号信息已获取，但接口本次没有返回可展示的额度窗口。" }
        return "点击刷新查询 \(snapshot.provider.displayName) 账号额度；本机用量显示在下方。"
    }
}
