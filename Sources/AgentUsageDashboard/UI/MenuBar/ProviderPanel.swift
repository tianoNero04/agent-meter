import SwiftUI
import Charts

struct ProviderPanel: View {
    let snapshot: ProviderSnapshot
    let refresh: () -> Void
    var slideEdge: Edge = .trailing

    /// 烘焙玻璃贴图存在时，卡片不再绘制自己的背景和边框，只承载内容。
    private var usesBakedBackground: Bool { BundleImages.cardStackBackground != nil }

    private var removalEdge: Edge { slideEdge == .trailing ? .leading : .trailing }

    var body: some View {
        ZStack {
            if let background = BundleImages.cardStackBackground {
                Image(nsImage: background)
                    .resizable()
                    .scaledToFill()
            }
            VStack(spacing: 9.5) {
                ProviderHeroCard(snapshot: snapshot, drawsBackground: !usesBakedBackground)
                QuotaCard(snapshot: snapshot, refresh: refresh, drawsBackground: !usesBakedBackground)
                TokenUsageCard(snapshot: snapshot, drawsBackground: !usesBakedBackground)
            }
            .id(snapshot.provider)
            .transition(.asymmetric(
                insertion: .move(edge: slideEdge).combined(with: .opacity),
                removal: .move(edge: removalEdge).combined(with: .opacity)
            ))
        }
    }
}

struct ProviderHeroCard: View {
    let snapshot: ProviderSnapshot
    var drawsBackground: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            ProviderIconTile(provider: snapshot.provider, size: 62)
            // 烘焙玻璃模式下对齐贴图第一条竖杠（95pt）：14 padding + 62 图标 + 33 = 109，杠右留 14
            Spacer().frame(width: drawsBackground ? 15 : 33)
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.provider.displayName)
                    .font(.system(size: 21, weight: .regular, design: .default))
                    .foregroundStyle(AppTheme.primaryText)
                StatusBadge(status: snapshot.status)
                if let error = snapshot.errorMessage {
                    Text("保留上次成功数据 · \(error)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.warning)
                        .lineLimit(1)
                }
            }
            Spacer()
            // 烘焙玻璃模式下对齐贴图第二条竖杠（224pt）：366 - 14 - 114 = 238 起，杠右留 14
            VStack(alignment: drawsBackground ? .trailing : .leading, spacing: 4) {
                Text("PLAN").font(.system(size: 8, weight: .regular, design: .monospaced)).foregroundStyle(AppTheme.secondaryText)
                Text(planLabel).font(.system(size: 16, weight: .regular, design: .default)).foregroundStyle(AppTheme.primaryText)
                Text("// ACCOUNT").font(.system(size: 7, design: .monospaced)).foregroundStyle(AppTheme.secondaryText)
            }
            .frame(width: drawsBackground ? nil : 114, alignment: .leading)
        }
        .padding(drawsBackground ? 10 : 14)
        .frame(height: 84.5)
        .background {
            if drawsBackground {
                Color.clear.panelBackground(accent: snapshot.provider.accentColor)
            } else {
                Color.clear.innerGlassFrame(verticalShift: 1.5, dimmed: true)
            }
        }
    }

    private var planLabel: String {
        guard let plan = snapshot.account?.planType, !plan.isEmpty else { return "本机" }
        return plan.uppercased()
    }
}

struct QuotaCard: View {
    let snapshot: ProviderSnapshot
    let refresh: () -> Void
    var drawsBackground: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("剩余额度").font(.system(size: 12, weight: .regular, design: .default)).foregroundStyle(AppTheme.primaryText)
                    Text("QUOTA REMAINING").font(.system(size: 7, weight: .regular, design: .monospaced)).tracking(1.0).foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.codex)
                        .padding(4)
                        .background(AppTheme.codex.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .help("刷新账号数据")
            }
            if drawsBackground { Divider().overlay(Color.white.opacity(0.13)) }
            if snapshot.windows.isEmpty {
                QuotaEmptyState(provider: snapshot.provider)
            } else {
                ForEach(snapshot.windows) { window in
                    RateLimitRow(window: window)
                    if drawsBackground, window.id != snapshot.windows.last?.id { Divider().overlay(Color.white.opacity(0.10)) }
                }
            }
        }
        .padding(drawsBackground ? 10 : 14)
        .frame(height: 154.5)
        .background {
            if drawsBackground {
                Color.clear.panelBackground(accent: snapshot.provider.accentColor)
            } else {
                Color.clear.innerGlassFrame()
            }
        }
    }
}

struct TokenUsageCard: View {
    let snapshot: ProviderSnapshot
    var drawsBackground: Bool = true

    private var totalTokens: Int { snapshot.accountUsage?.lifetimeTokens ?? snapshot.localTokenUsage.total }
    private var buckets: [DailyTokenBucket] {
        recentSevenDayBuckets(snapshot.provider == .codex ? (snapshot.accountUsage?.dailyBuckets ?? []) : snapshot.localDailyBuckets)
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("已使用 Token").font(.system(size: 14, weight: .regular, design: .default)).foregroundStyle(AppTheme.primaryText)
                Text("TOKEN USAGE · 7 DAYS").font(.system(size: 7, weight: .regular, design: .monospaced)).tracking(0.5).foregroundStyle(AppTheme.secondaryText)
                HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.codex)
                    .frame(width: 20, height: 20)
                    .background(AppTheme.codex.opacity(0.10), in: Circle())
                    Text(formatCompactNumber(totalTokens)).font(.system(size: 16, weight: .regular, design: .monospaced)).foregroundStyle(AppTheme.primaryText)
                }
            }
            Spacer(minLength: 4)
            if buckets.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "chart.xyaxis.line").font(.system(size: 16, weight: .regular)).foregroundStyle(AppTheme.secondaryText)
                    Text("暂无曲线").font(.system(size: 8, weight: .regular)).foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            } else {
                Chart(buckets) { bucket in
                    AreaMark(x: .value("日期", bucket.startDate, unit: .day), y: .value("Token", bucket.tokens))
                        .foregroundStyle(LinearGradient(colors: [AppTheme.codex.opacity(0.36), .clear], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("日期", bucket.startDate, unit: .day), y: .value("Token", bucket.tokens))
                        .foregroundStyle(AppTheme.codex)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("日期", bucket.startDate, unit: .day), y: .value("Token", bucket.tokens))
                        .foregroundStyle(AppTheme.primaryText)
                        .symbolSize(20)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
        }
        .padding(drawsBackground ? 10 : 14)
        .frame(height: 86)
        .background {
            if drawsBackground {
                Color.clear.panelBackground(accent: snapshot.provider.accentColor)
            } else {
                Color.clear.innerGlassFrame(verticalShift: -1.5)
            }
        }
    }
}

/// 额度空态：与 RateLimitRow 同一骨架、同一字号，百分比显示 "--"，不编造数字。
/// 所有 provider 共用，保证剩余额度卡在任何状态下排版一致。
struct QuotaEmptyState: View {
    let provider: Provider

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("账号额度").font(.system(size: 11, weight: .regular)).foregroundStyle(AppTheme.primaryText)
                    Text("ACCOUNT QUOTA").font(.system(size: 7, weight: .regular, design: .monospaced)).tracking(0.5).foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Text("--").font(.system(size: 18, weight: .regular, design: .monospaced)).foregroundStyle(AppTheme.secondaryText)
            }
            Capsule().fill(Color.white.opacity(0.12))
                .frame(height: 4)
            Text(provider == .kimiCode ? "暂未连接账号，仅显示本机 Token。" : "刷新时从 Codex App Server 获取，暂未拿到数据。")
                .font(.system(size: 7, design: .monospaced)).foregroundStyle(AppTheme.secondaryText)
        }
    }
}
