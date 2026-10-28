import SwiftUI

struct MonitoringDashboardView: View {
    @ObservedObject var model: DashboardModel
    @State private var granularity: TimeGranularity = .daily
    @State private var selectedBucketID: String?
    @State private var pricing: PricingPreferences
    private let pricingStore: PricingSettingsStore

    init(model: DashboardModel, pricingStore: PricingSettingsStore = UserDefaultsPricingSettingsStore()) {
        self.model = model
        self.pricingStore = pricingStore
        self._pricing = State(initialValue: pricingStore.load())
    }

    var body: some View {
        let aggregator = MonitoringAggregator()
        let buckets = aggregator.aggregateBuckets(codex: model.snapshot(for: .codex), kimi: model.snapshot(for: .kimiCode), granularity: granularity, pricing: pricing)
        let selected = buckets.first { $0.id == selectedBucketID }
        let rows = aggregator.aggregateBreakdown(buckets: buckets, selectedBucket: selected)
        let summary = aggregator.calculateSummary(buckets: buckets, selectedBucket: selected, pricing: pricing)

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Token 统计").font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Picker("汇总粒度", selection: $granularity) {
                        ForEach(TimeGranularity.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                Text("Codex、Kimi Code · \(scopeDescription(buckets: buckets, selected: selected))")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)

                HStack(alignment: .top, spacing: 0) {
                    metric("范围内 Token", value: formatCompactNumber(summary.totalTokens), detail: summary.tokensDeltaRatio.map { String(format: "最近一时段环比 %+.1f%%", $0 * 100) } ?? "暂无可比较的上一时段")
                    metric("缓存命中率（估算）", value: String(format: "%.1f%%", summary.cacheHitRate * 100), detail: "缓存折算节省 \(summary.cacheSavingsDisplay)")
                    metric("API 费率折算", value: String(format: "%@%.2f", pricing.targetCurrency.symbol, summary.totalEstimatedCost), detail: "估算金额，非实际账单")
                }
                .panelBackground()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Token 消耗分布").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(selected == nil ? "点击查看该时段" : "再次点击返回全部")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(buckets) { bucket in
                            Button {
                                selectedBucketID = selectedBucketID == bucket.id ? nil : bucket.id
                            } label: {
                                VStack(spacing: 7) {
                                    Spacer(minLength: 0)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(selectedBucketID == bucket.id ? AppTheme.accent : AppTheme.secondaryText.opacity(0.55))
                                        .frame(height: max(3, 96 * CGFloat(bucket.totalTokens) / CGFloat(max(1, buckets.map(\.totalTokens).max() ?? 1))))
                                    Text(bucket.label)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 125)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("\(bucket.fullDescription)：\(bucket.totalTokens) Token")
                            .accessibilityLabel("\(bucket.fullDescription)，\(bucket.totalTokens) Token")
                            .accessibilityAddTraits(selectedBucketID == bucket.id ? .isSelected : [])
                        }
                    }
                }
                .padding(16)
                .panelBackground()

                AdaptiveTable(minimumWidth: 600) {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text("服务商").frame(maxWidth: .infinity, alignment: .leading)
                            Text("占比").frame(width: 52, alignment: .trailing)
                            Text("输入估算").frame(width: 64, alignment: .trailing)
                            Text("缓存估算").frame(width: 64, alignment: .trailing)
                            Text("输出/推理估算").frame(width: 84, alignment: .trailing)
                            Text("折算金额").frame(width: 90, alignment: .trailing)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(14)
                        ForEach(rows) { row in
                            Divider()
                            HStack(spacing: 10) {
                                Text(row.provider.displayName).frame(maxWidth: .infinity, alignment: .leading)
                                Text(String(format: "%.1f%%", row.shareRatio * 100)).frame(width: 52, alignment: .trailing)
                                Text(formatCompactNumber(row.inputTokens)).frame(width: 64, alignment: .trailing)
                                Text(formatCompactNumber(row.cachedTokens)).frame(width: 64, alignment: .trailing)
                                Text(formatCompactNumber(row.outputTokens)).frame(width: 84, alignment: .trailing)
                                Text(String(format: "%@%.2f", pricing.targetCurrency.symbol, row.estimatedCost)).frame(width: 90, alignment: .trailing)
                            }
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .lineLimit(1)
                            .padding(14)
                        }
                    }
                    .panelBackground()
                }

                Text("摘要和明细使用相同日期范围。输入、缓存、输出及费用按本机累计构成和模型费率估算；缺少构成时按输入估算。未记录真实请求数，因此不展示会话或请求次数。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .foregroundStyle(AppTheme.primaryText)
        }
        .onAppear { pricing = pricingStore.load() }
        .onChange(of: granularity) { _ in selectedBucketID = nil }
    }

    private func metric(_ title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12)).foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail).font(.system(size: 11)).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(12)
    }

    private func scopeDescription(buckets: [TokenDistributionBucket], selected: TokenDistributionBucket?) -> String {
        if let selected { return selected.fullDescription }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        let first = buckets.first.map { formatter.string(from: $0.startDate) } ?? "—"
        let end = formatter.string(from: Date())
        let grouping: String
        switch granularity {
        case .daily: grouping = "近 7 天，按日汇总"
        case .weekly: grouping = "近 28 天，按 7 天汇总"
        case .monthly: grouping = "近 3 个自然月，按月汇总"
        }
        return "\(first)–\(end)（\(grouping)）"
    }
}
