import SwiftUI

/// 像素级复刻 ReactBits Pro monitoring-8 风格的 Token 用量与响应大盘
/// 具备：日/周/月多粒度切换、柱状图点击下钻 Provider 细分、指标看板联动
struct MonitoringDashboardView: View {
    @ObservedObject var model: DashboardModel

    /// 当前选中的时间粒度（日 / 周 / 月）
    @State private var granularity: TimeGranularity = .daily
    /// 当前用户点击选中的柱子（用于下钻，为 nil 时展示全局汇总）
    @State private var selectedBucket: TokenDistributionBucket? = nil
    /// 鼠标悬停的柱子 ID
    @State private var hoveredBucketId: String? = nil

    /// 计费偏好设置仓库
    private let pricingStore: PricingSettingsStore
    @State private var pricing: PricingPreferences

    init(model: DashboardModel, pricingStore: PricingSettingsStore = UserDefaultsPricingSettingsStore()) {
        self.model = model
        self.pricingStore = pricingStore
        self._pricing = State(initialValue: pricingStore.load())
    }

    // MARK: - ReactBits Monitoring-8 设计系统色彩令牌
    private enum Theme {
        static let canvasBg = Color(red: 9/255, green: 9/255, blue: 11/255)       // neutral-950 #09090b
        static let cardBg = Color(red: 24/255, green: 24/255, blue: 27/255)       // neutral-900 #18181b
        static let border = Color(red: 39/255, green: 39/255, blue: 42/255)       // neutral-800 #27272a
        static let barDefault = Color(red: 63/255, green: 63/255, blue: 70/255)   // oklch(0.371 0 0) #3f3f46
        static let barCoral = Color(red: 251/255, green: 113/255, blue: 133/255) // oklch(0.704 0.191 22.216) #fb7185
        static let greenMetric = Color(red: 52/255, green: 211/255, blue: 153/255) // oklch(0.792 0.209 151.711) #34d399
        static let textMuted = Color(red: 161/255, green: 161/255, blue: 170/255) // neutral-400 #a1a1aa
        static let textDim = Color(red: 113/255, green: 113/255, blue: 122/255)   // neutral-500 #71717a
    }

    private var aggregator: MonitoringAggregator {
        MonitoringAggregator()
    }

    private var currentBuckets: [TokenDistributionBucket] {
        aggregator.aggregateBuckets(
            codex: model.snapshot(for: .codex),
            kimi: model.snapshot(for: .kimiCode),
            granularity: granularity,
            pricing: pricing
        )
    }

    private var summary: MonitoringOverviewSummary {
        aggregator.calculateSummary(
            buckets: currentBuckets,
            selectedBucket: selectedBucket,
            pricing: pricing
        )
    }

    private var tableItems: [ProviderBreakdownItem] {
        if let selected = selectedBucket {
            return selected.providerBreakdown
        }
        // 未选中特定柱子时，汇总所有分桶中的提供商数据
        var codexTokens = 0
        var kimiTokens = 0
        for b in currentBuckets {
            codexTokens += b.codexTokens
            kimiTokens += b.kimiTokens
        }
        return aggregator.aggregateBuckets(
            codex: model.snapshot(for: .codex),
            kimi: model.snapshot(for: .kimiCode),
            granularity: .daily,
            pricing: pricing
        ).first?.providerBreakdown ?? []
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // 主监控外卡（复刻 monitoring-8 容器外框）
                VStack(alignment: .leading, spacing: 18) {
                    // 1. 顶栏刊头：标题、副标题、下钻状态与日/周/月切换器
                    headerRow

                    // 2. 核心三联指标卡 (p50 / p90 / p99 样式卡片)
                    metricCardsRow

                    // 3. 柱状图区域 (Latency distribution -> Token 消耗分布)
                    histogramSection

                    // 4. 下钻细分表格 (Route -> Provider / Model 表格)
                    providerDrilldownTable
                }
                .padding(20)
                .background(Theme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
            .padding(20)
        }
        .background(Theme.canvasBg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - 1. 顶栏刊头
    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Response times // Token 用量大盘")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                if let selected = selectedBucket {
                    HStack(spacing: 6) {
                        Text("已下钻：\(selected.fullDescription)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.barCoral)

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedBucket = nil
                            }
                        } label: {
                            Text("✕ 清除筛选")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.textMuted)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    let rangeDesc = granularity == .daily ? "最近 7 天" : (granularity == .weekly ? "最近 4 周" : "最近 3 个月")
                    Text("\(rangeDesc) · \(formatCompactNumber(summary.totalTokens)) Tokens · 2 个提供商")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                // 状态/告警指示器微标
                HStack(spacing: 6) {
                    Circle()
                        .fill(selectedBucket != nil ? Theme.barCoral : Theme.greenMetric)
                        .frame(width: 6, height: 6)
                    Text(selectedBucket != nil ? "下钻聚焦模式" : "用量监测正常")
                        .font(.system(size: 12))
                        .foregroundStyle(selectedBucket != nil ? Theme.barCoral : Theme.textMuted)
                }
                .padding(.trailing, 4)

                // [ 日 | 周 | 月 ] 颗粒度分段切换器
                HStack(spacing: 2) {
                    ForEach(TimeGranularity.allCases) { g in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                granularity = g
                                selectedBucket = nil
                            }
                        } label: {
                            Text(g.rawValue)
                                .font(.system(size: 12, weight: granularity == g ? .semibold : .regular))
                                .foregroundStyle(granularity == g ? .white : Theme.textMuted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(granularity == g ? Theme.border : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color(red: 18/255, green: 18/255, blue: 20/255))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 2. 三联指标卡片
    private var metricCardsRow: some View {
        HStack(spacing: 12) {
            // Card 1: p50 · 消耗总量
            metricCard(
                label: selectedBucket != nil ? "p50 · 当前所选周期消耗" : "p50 · 周期 Token 总消耗",
                value: formatTokens(summary.totalTokens),
                badgeText: summary.tokensDeltaRatio.map { String(format: "%.1f%%", abs($0 * 100)) } ?? "0.0%",
                badgeIsIncrease: (summary.tokensDeltaRatio ?? 0) >= 0,
                badgePrefix: (summary.tokensDeltaRatio ?? 0) >= 0 ? "↑" : "↓"
            )

            // Card 2: p90 · 缓存命中与节省
            metricCard(
                label: "p90 · Prompt 缓存命中率",
                value: String(format: "%.1f%%", summary.cacheHitRate * 100),
                badgeText: "省 \(summary.cacheSavingsDisplay)",
                badgeIsIncrease: false,
                customBadgeColor: Theme.greenMetric
            )

            // Card 3: p99 · 预估算力支出
            metricCard(
                label: "p99 · 预估算力折算法币",
                value: String(format: "%@%.2f", pricing.targetCurrency.symbol, summary.totalEstimatedCost),
                badgeText: "\(summary.totalRequestsCount) 次会话",
                badgeIsIncrease: true,
                customBadgeColor: Theme.barCoral
            )
        }
    }

    private func metricCard(
        label: String,
        value: String,
        badgeText: String,
        badgeIsIncrease: Bool,
        badgePrefix: String = "",
        customBadgeColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // 变化率 / 说明徽标
                HStack(spacing: 2) {
                    if !badgePrefix.isEmpty {
                        Text(badgePrefix)
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text(badgeText)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(customBadgeColor ?? (badgeIsIncrease ? Theme.barCoral : Theme.greenMetric))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 20/255, green: 20/255, blue: 23/255))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    // MARK: - 3. 柱状图区域
    private var histogramSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Token distribution // 消耗时序分布")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text(selectedBucket != nil ? "再次点击柱子可取消选中" : "点击柱子可下钻 Provider 明细")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textDim)
            }

            let buckets = currentBuckets
            let maxTokens = max(1, buckets.map(\.totalTokens).max() ?? 1)

            // 柱状图主图表 (高度 120pt)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(buckets) { bucket in
                    let isSelected = selectedBucket?.id == bucket.id
                    let isHovered = hoveredBucketId == bucket.id
                    // 高于 75% 峰值的柱子默认微亮，选中的柱子高亮为珊瑚红
                    let isPeak = bucket.totalTokens > Int(Double(maxTokens) * 0.75) && bucket.totalTokens > 0
                    let barColor: Color = isSelected
                        ? Theme.barCoral
                        : (isPeak ? Theme.barCoral.opacity(0.85) : Theme.barDefault)

                    // 柱子高度计算（最小 6pt，最大 100pt）
                    let ratio = CGFloat(bucket.totalTokens) / CGFloat(maxTokens)
                    let barHeight: CGFloat = bucket.totalTokens > 0 ? max(8, ratio * 96) : 4

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            if selectedBucket?.id == bucket.id {
                                selectedBucket = nil
                            } else {
                                selectedBucket = bucket
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            // 柱子主体
                            ZStack(alignment: .bottom) {
                                // 柱子背景槽位（悬停时微亮）
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                                // 填充色柱
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(barColor)
                                    .frame(height: barHeight)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(isSelected ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
                            }
                            .frame(height: 100)

                            // 底部 X 轴时间标签
                            Text(bucket.label)
                                .font(.system(size: 11, weight: isSelected ? .bold : .regular, design: .monospaced))
                                .foregroundStyle(isSelected ? .white : Theme.textDim)
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { hovered in
                        hoveredBucketId = hovered ? bucket.id : nil
                    }
                    .help("\(bucket.fullDescription): \(formatCompactNumber(bucket.totalTokens)) Tokens")
                }
            }
            .frame(height: 125)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .padding(14)
        .background(Color(red: 20/255, green: 20/255, blue: 23/255))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    // MARK: - 4. 下钻 Provider 细分表格
    private var providerDrilldownTable: some View {
        VStack(spacing: 0) {
            // 表头
            HStack(spacing: 12) {
                Text("Provider / 提供商")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("占比 / 会话")
                    .frame(width: 80, alignment: .trailing)
                Text("输入 Input")
                    .frame(width: 85, alignment: .trailing)
                Text("缓存 Cached")
                    .frame(width: 85, alignment: .trailing)
                Text("输出 Output")
                    .frame(width: 85, alignment: .trailing)
                Text("预估成本 Cost")
                    .frame(width: 90, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.textDim)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()
                .background(Theme.border)

            // 表格行（Codex 与 Kimi）
            ForEach(currentTableRows) { row in
                tableRowView(row: row)

                Divider()
                    .background(Theme.border.opacity(0.6))
            }
        }
        .background(Color(red: 20/255, green: 20/255, blue: 23/255))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// 当前要展示的行数据
    private var currentTableRows: [ProviderBreakdownItem] {
        if let selected = selectedBucket {
            return selected.providerBreakdown
        }
        // 全局汇总行
        let codexSnapshot = model.snapshot(for: .codex)
        let kimiSnapshot = model.snapshot(for: .kimiCode)

        var totalCodex = 0
        var totalKimi = 0
        for b in currentBuckets {
            totalCodex += b.codexTokens
            totalKimi += b.kimiTokens
        }
        let total = totalCodex + totalKimi

        let codexRatio = total > 0 ? Double(totalCodex) / Double(total) : 0.0
        let kimiRatio = total > 0 ? Double(totalKimi) / Double(total) : 0.0

        let codexPricing = pricing.pricing(for: "gpt-4o")
        let kimiPricing = pricing.pricing(for: "moonshot-v1-8k")

        let codexCost = codexPricing.calculateCost(for: codexSnapshot.localTokenUsage, targetCurrency: pricing.targetCurrency, exchangeRate: pricing.usdToCnyRate)
        let kimiCost = kimiPricing.calculateCost(for: kimiSnapshot.localTokenUsage, targetCurrency: pricing.targetCurrency, exchangeRate: pricing.usdToCnyRate)

        return [
            ProviderBreakdownItem(
                provider: .codex,
                displayName: "Codex (CLI & App Server)",
                badgeText: "CODEX",
                requestsCount: max(totalCodex > 0 ? 1 : 0, Int(round(Double(totalCodex) / 1200.0))),
                inputTokens: codexSnapshot.localTokenUsage.input,
                cachedTokens: codexSnapshot.localTokenUsage.cachedInput,
                outputTokens: codexSnapshot.localTokenUsage.output,
                totalTokens: totalCodex,
                shareRatio: codexRatio,
                estimatedCost: codexCost
            ),
            ProviderBreakdownItem(
                provider: .kimiCode,
                displayName: "Kimi Code (Moonshot API)",
                badgeText: "KIMI",
                requestsCount: max(totalKimi > 0 ? 1 : 0, Int(round(Double(totalKimi) / 1500.0))),
                inputTokens: kimiSnapshot.localTokenUsage.input,
                cachedTokens: kimiSnapshot.localTokenUsage.cachedInput,
                outputTokens: kimiSnapshot.localTokenUsage.output,
                totalTokens: totalKimi,
                shareRatio: kimiRatio,
                estimatedCost: kimiCost
            )
        ]
    }

    private func tableRowView(row: ProviderBreakdownItem) -> some View {
        HStack(spacing: 12) {
            // 提供商名称与类 POST/GET 徽标
            HStack(spacing: 8) {
                Text(row.badgeText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(row.provider == .codex ? Theme.greenMetric : Color(red: 96/255, green: 165/255, blue: 250/255))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(row.provider == .codex ? Color(red: 19/255, green: 46/255, blue: 34/255) : Color(red: 30/255, green: 38/255, blue: 56/255))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text(row.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 占比 / 请求
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.1f%%", row.shareRatio * 100))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                Text("\(row.requestsCount) reqs")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textDim)
            }
            .frame(width: 80, alignment: .trailing)

            // 输入
            Text(formatCompactNumber(row.inputTokens))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 85, alignment: .trailing)

            // 缓存读取
            Text(formatCompactNumber(row.cachedTokens))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.greenMetric)
                .frame(width: 85, alignment: .trailing)

            // 输出
            Text(formatCompactNumber(row.outputTokens))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 85, alignment: .trailing)

            // 预估成本
            Text(String(format: "%@%.2f", pricing.targetCurrency.symbol, row.estimatedCost))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.barCoral)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 辅助格式化方法
    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.2fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000.0)
        }
        return "\(count)"
    }

    private func formatCompactNumber(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.0fk", Double(count) / 1_000.0)
        }
        return "\(count)"
    }
}
