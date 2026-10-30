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
        VStack(spacing: 7) {
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
            ProviderIconTile(provider: snapshot.provider, size: 44, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 3.5) {
                Text(snapshot.provider.displayName.uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.primaryText)
                Text(heroDetail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(snapshot.errorMessage == nil ? AppTheme.secondaryText : AppTheme.warning)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(heroDetail)
            .accessibilityLabel(heroDetail)

            HStack(spacing: 10) {
                Text(planLabel)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(snapshot.account == nil ? AppTheme.secondaryText : AppTheme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: min(CGFloat(planLabel.count) * 7.2, 88), alignment: .trailing)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.heroLight.opacity(0.8))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(AppTheme.heroGreen.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.heroLight.opacity(0.30), lineWidth: 0.75))
            .help(planLabel)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 74)
        // Decorative gradients extend beyond the card; clipping does not constrain hit testing.
        .background(HeroAuroraBackground().allowsHitTesting(false))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.heroLight.opacity(0.18), lineWidth: 0.75)
        )
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
}

private struct HeroAuroraBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                // Keep the reading area dark; concentrate illumination in the upper right.
                LinearGradient(
                    colors: [AppTheme.heroBackground, AppTheme.heroDeepTeal],
                    startPoint: .leading, endPoint: .trailing
                )
                RadialGradient(
                    stops: [
                        .init(color: AppTheme.heroLight, location: 0),
                        .init(color: AppTheme.heroMint, location: 0.12),
                        .init(color: AppTheme.heroMint.opacity(0.64), location: 0.30),
                        .init(color: AppTheme.heroMint.opacity(0.16), location: 0.62),
                        .init(color: .clear, location: 1)
                    ],
                    center: UnitPoint(x: 0.99, y: -0.10),
                    startRadius: 0, endRadius: width * 0.55
                )
                // A dark lower plane gives the light a crisp curved boundary, not a blurred stripe.
                lowerPlane(width: width, height: height)
                    .fill(LinearGradient(
                        stops: [
                            .init(color: AppTheme.heroDeepTeal.opacity(0.05), location: 0),
                            .init(color: AppTheme.heroDeepTeal.opacity(0.86), location: 0.48),
                            .init(color: AppTheme.heroBackground, location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                auroraPath(width: width, height: height)
                    .stroke(AppTheme.heroMint.opacity(0.55), lineWidth: 0.45)
                // Secondary light emerges at the bottom where the curve enters the card.
                RadialGradient(
                    colors: [AppTheme.heroMint.opacity(0.55), .clear],
                    center: UnitPoint(x: 0.56, y: 1.14),
                    startRadius: 0, endRadius: width * 0.17
                )
                LinearGradient(
                    stops: [
                        .init(color: AppTheme.heroBackground.opacity(0.75), location: 0),
                        .init(color: AppTheme.heroBackground.opacity(0.52), location: 0.40),
                        .init(color: .clear, location: 0.67)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            }
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func auroraPath(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: width * 0.56, y: height * 1.02))
            path.addCurve(
                to: CGPoint(x: width * 1.02, y: -height * 0.08),
                control1: CGPoint(x: width * 0.68, y: height * 0.20),
                control2: CGPoint(x: width * 0.89, y: height * 0.42)
            )
        }
    }

    private func lowerPlane(width: CGFloat, height: CGFloat) -> Path {
        var path = auroraPath(width: width, height: height)
        path.addLine(to: CGPoint(x: width * 1.02, y: height * 1.02))
        path.closeSubpath()
        return path
    }
}

private struct QuotaAuroraBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [AppTheme.heroBackground, AppTheme.heroDeepTeal.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [AppTheme.heroMint.opacity(0.17), AppTheme.heroGreen.opacity(0.08), .clear],
                    center: UnitPoint(x: 0.94, y: 0.02),
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.64
                )
                RadialGradient(
                    colors: [AppTheme.heroGreen.opacity(0.10), .clear],
                    center: UnitPoint(x: 0.04, y: 0.52),
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.36
                )
            }
            .clipped()
        }
        .accessibilityHidden(true)
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
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer(minLength: 4)

                if pages.count > 1 {
                    pageControls
                } else if let lastRefresh {
                    Text("最后更新 \(lastRefresh.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .help("最近刷新：\(lastRefresh.formatted())")
                }

                Button(action: refresh) {
                    Group {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppTheme.heroMint)
                                .shadow(color: AppTheme.heroMint.opacity(0.65), radius: 3)
                        }
                    }
                    .frame(width: 14, height: 14)
                    .padding(5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressBounceButtonStyle(reduceMotion: reduceMotion))
                .disabled(isRefreshing)
                .opacity(isRefreshing ? 0.65 : 1)
                .help("刷新账号额度")
                .accessibilityLabel(isRefreshing ? "正在刷新账号额度" : "刷新账号额度")
            }
            .padding(.horizontal, 13)
            .frame(height: 36)

            if snapshot.windows.isEmpty {
                QuotaEmptyState(snapshot: snapshot)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 5) {
                    ForEach(visibleWindows) { window in
                        RateLimitRow(window: window)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.bottom, 10)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(height: 154, alignment: .top)
        .background(QuotaAuroraBackground().allowsHitTesting(false))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.heroLight.opacity(0.16), lineWidth: 0.75)
        )
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("本机 Token")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("近 7 日")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(formatCompactNumber(snapshot.localTokenUsage.total))
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.primaryText)
                        .accessibilityLabel("本机累计 \(snapshot.localTokenUsage.total) Token")
                    if snapshot.localTokenUsage.cachedInput > 0 {
                        HStack(spacing: 3) {
                            Text("缓存")
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("\(Int(round(snapshot.localTokenUsage.cacheHitRate * 100)))%")
                                .foregroundStyle(AppTheme.accent)
                        }
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 2, style: .continuous))
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
                .frame(width: 124, alignment: .leading)

                Rectangle()
                    .fill(AppTheme.hairline)
                    .frame(width: 0.75, height: 44)

                if buckets.isEmpty {
                    VStack(spacing: 3) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.tertiaryText)
                        Text("暂无本机趋势")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                } else {
                    Chart(buckets) { bucket in
                        LineMark(x: .value("日期", bucket.startDate, unit: .day), y: .value("Token", bucket.tokens))
                            .foregroundStyle(AppTheme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("日期", bucket.startDate, unit: .day), y: .value("Token", bucket.tokens))
                            .foregroundStyle(AppTheme.primaryText)
                            .symbolSize(18)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .accessibilityLabel(chartSummary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 98)
        .panelBackground()
    }
}

struct QuotaEmptyState: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
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
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous))
            }
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(Color.white.opacity(0.05))
                        .frame(maxWidth: .infinity, maxHeight: 6)
                }
            }
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(snapshot.errorMessage == nil ? AppTheme.secondaryText : AppTheme.warning)
                .lineLimit(2)
                .help(description)
                .accessibilityLabel(description)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                .fill(AppTheme.background.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 0.75)
                )
        )
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
