import Foundation

/// 监控大盘数据聚合计算器：负责将各 Provider 的原始会话与历史快照分桶聚合为日/周/月视图，并计算下钻与核心指标
struct MonitoringAggregator: Sendable {
    let calendar: Calendar
    let now: Date

    init(calendar: Calendar = .current, now: Date = Date()) {
        self.calendar = calendar
        self.now = now
    }

    /// 聚合指定时间粒度的柱状图分布分桶
    func aggregateBuckets(
        codex: ProviderSnapshot,
        kimi: ProviderSnapshot,
        granularity: TimeGranularity,
        pricing: PricingPreferences
    ) -> [TokenDistributionBucket] {
        switch granularity {
        case .daily:
            return aggregateDaily(codex: codex, kimi: kimi, count: 7, pricing: pricing)
        case .weekly:
            return aggregateWeekly(codex: codex, kimi: kimi, count: 4, pricing: pricing)
        case .monthly:
            return aggregateMonthly(codex: codex, kimi: kimi, count: 3, pricing: pricing)
        }
    }

    /// 聚合每日分桶（默认最近 7 天）
    private func aggregateDaily(
        codex: ProviderSnapshot,
        kimi: ProviderSnapshot,
        count: Int,
        pricing: PricingPreferences
    ) -> [TokenDistributionBucket] {
        var buckets: [TokenDistributionBucket] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"
        let fullDateFormatter = DateFormatter()
        fullDateFormatter.dateFormat = "yyyy-MM-dd (EE)"
        fullDateFormatter.locale = Locale(identifier: "zh_CN")

        let today = calendar.startOfDay(for: now)

        for offset in (0..<count).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }

            let codexTokens = findTokens(in: codex.localDailyBuckets, forDay: day)
            let kimiTokens = findTokens(in: kimi.localDailyBuckets, forDay: day)
            let total = codexTokens + kimiTokens

            let breakdown = buildBreakdown(
                codexTokens: codexTokens,
                kimiTokens: kimiTokens,
                codexSnapshot: codex,
                kimiSnapshot: kimi,
                pricing: pricing
            )

            buckets.append(
                TokenDistributionBucket(
                    startDate: day,
                    label: dateFormatter.string(from: day),
                    fullDescription: fullDateFormatter.string(from: day),
                    totalTokens: total,
                    codexTokens: codexTokens,
                    kimiTokens: kimiTokens,
                    providerBreakdown: breakdown
                )
            )
        }

        return buckets
    }

    /// 聚合每周分桶（默认最近 4 周）
    private func aggregateWeekly(
        codex: ProviderSnapshot,
        kimi: ProviderSnapshot,
        count: Int,
        pricing: PricingPreferences
    ) -> [TokenDistributionBucket] {
        var buckets: [TokenDistributionBucket] = []
        let today = calendar.startOfDay(for: now)

        for weekOffset in (0..<count).reversed() {
            let daysBack = weekOffset * 7
            guard let weekStart = calendar.date(byAdding: .day, value: -(daysBack + 6), to: today),
                  let weekEnd = calendar.date(byAdding: .day, value: -daysBack, to: today) else { continue }

            var codexTokens = 0
            var kimiTokens = 0

            var currentDay = weekStart
            while currentDay <= weekEnd {
                codexTokens += findTokens(in: codex.localDailyBuckets, forDay: currentDay)
                kimiTokens += findTokens(in: kimi.localDailyBuckets, forDay: currentDay)
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
                currentDay = next
            }

            let weekOfYear = calendar.component(.weekOfYear, from: weekEnd)
            let label = "W\(weekOfYear)"

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd"
            let desc = "\(dateFormatter.string(from: weekStart)) ~ \(dateFormatter.string(from: weekEnd))"

            let breakdown = buildBreakdown(
                codexTokens: codexTokens,
                kimiTokens: kimiTokens,
                codexSnapshot: codex,
                kimiSnapshot: kimi,
                pricing: pricing
            )

            buckets.append(
                TokenDistributionBucket(
                    startDate: weekStart,
                    label: label,
                    fullDescription: desc,
                    totalTokens: codexTokens + kimiTokens,
                    codexTokens: codexTokens,
                    kimiTokens: kimiTokens,
                    providerBreakdown: breakdown
                )
            )
        }

        return buckets
    }

    /// 聚合每月分桶（默认最近 3 个月）
    private func aggregateMonthly(
        codex: ProviderSnapshot,
        kimi: ProviderSnapshot,
        count: Int,
        pricing: PricingPreferences
    ) -> [TokenDistributionBucket] {
        var buckets: [TokenDistributionBucket] = []
        let today = calendar.startOfDay(for: now)

        for monthOffset in (0..<count).reversed() {
            guard let targetDate = calendar.date(byAdding: .month, value: -monthOffset, to: today),
                  let interval = calendar.dateInterval(of: .month, for: targetDate) else { continue }

            var codexTokens = 0
            var kimiTokens = 0

            var currentDay = interval.start
            while currentDay < interval.end && currentDay <= today {
                codexTokens += findTokens(in: codex.localDailyBuckets, forDay: currentDay)
                kimiTokens += findTokens(in: kimi.localDailyBuckets, forDay: currentDay)
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
                currentDay = next
            }

            let month = calendar.component(.month, from: interval.start)
            let label = "\(month)月"

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy年MM月"
            let desc = dateFormatter.string(from: interval.start)

            let breakdown = buildBreakdown(
                codexTokens: codexTokens,
                kimiTokens: kimiTokens,
                codexSnapshot: codex,
                kimiSnapshot: kimi,
                pricing: pricing
            )

            buckets.append(
                TokenDistributionBucket(
                    startDate: interval.start,
                    label: label,
                    fullDescription: desc,
                    totalTokens: codexTokens + kimiTokens,
                    codexTokens: codexTokens,
                    kimiTokens: kimiTokens,
                    providerBreakdown: breakdown
                )
            )
        }

        return buckets
    }

    /// 在给定 Provider 的本地日分桶中匹配指定某一天的 Token 消耗
    private func findTokens(in buckets: [DailyTokenBucket], forDay day: Date) -> Int {
        for b in buckets {
            if calendar.isDate(b.startDate, inSameDayAs: day) {
                return b.tokens
            }
        }
        return 0
    }

    /// 构造当前时段各提供商的细分下钻明细（按实际消耗或总体比例换算）
    private func buildBreakdown(
        codexTokens: Int,
        kimiTokens: Int,
        codexSnapshot: ProviderSnapshot,
        kimiSnapshot: ProviderSnapshot,
        pricing: PricingPreferences
    ) -> [ProviderBreakdownItem] {
        let total = codexTokens + kimiTokens
        var items: [ProviderBreakdownItem] = []

        // Codex 细分项
        let codexRatio = total > 0 ? Double(codexTokens) / Double(total) : 0.0
        let codexUsage = prorateUsage(snapshotUsage: codexSnapshot.localTokenUsage, totalTokens: codexTokens)
        let codexPricing = pricing.pricing(for: "gpt-4o")
        let codexCost = codexPricing.calculateCost(
            for: codexUsage,
            targetCurrency: pricing.targetCurrency,
            exchangeRate: pricing.usdToCnyRate
        )
        let codexRequests = max(codexTokens > 0 ? 1 : 0, Int(round(Double(codexTokens) / 1200.0)))

        items.append(
            ProviderBreakdownItem(
                provider: .codex,
                displayName: "Codex (CLI & App Server)",
                badgeText: "CODEX",
                requestsCount: codexRequests,
                inputTokens: codexUsage.input,
                cachedTokens: codexUsage.cachedInput,
                outputTokens: codexUsage.output,
                totalTokens: codexTokens,
                shareRatio: codexRatio,
                estimatedCost: codexCost
            )
        )

        // Kimi 细分项
        let kimiRatio = total > 0 ? Double(kimiTokens) / Double(total) : 0.0
        let kimiUsage = prorateUsage(snapshotUsage: kimiSnapshot.localTokenUsage, totalTokens: kimiTokens)
        let kimiPricing = pricing.pricing(for: "moonshot-v1-8k")
        let kimiCost = kimiPricing.calculateCost(
            for: kimiUsage,
            targetCurrency: pricing.targetCurrency,
            exchangeRate: pricing.usdToCnyRate
        )
        let kimiRequests = max(kimiTokens > 0 ? 1 : 0, Int(round(Double(kimiTokens) / 1500.0)))

        items.append(
            ProviderBreakdownItem(
                provider: .kimiCode,
                displayName: "Kimi Code (Moonshot API)",
                badgeText: "KIMI",
                requestsCount: kimiRequests,
                inputTokens: kimiUsage.input,
                cachedTokens: kimiUsage.cachedInput,
                outputTokens: kimiUsage.output,
                totalTokens: kimiTokens,
                shareRatio: kimiRatio,
                estimatedCost: kimiCost
            )
        )

        return items
    }

    /// 根据该 Provider 本地历史总体的 Input/Cache/Output 构成比例，按分桶总 Tokens 等比估算分桶内的组成
    private func prorateUsage(snapshotUsage: TokenUsage, totalTokens: Int) -> TokenUsage {
        guard totalTokens > 0 else { return .zero }
        let snapTotal = snapshotUsage.total
        guard snapTotal > 0 else {
            // 若没有历史详细记录，提供经验基线比例：60% input, 25% cache, 15% output
            let input = Int(Double(totalTokens) * 0.60)
            let cache = Int(Double(totalTokens) * 0.25)
            let output = max(0, totalTokens - input - cache)
            return TokenUsage(input: input, cachedInput: cache, output: output)
        }

        let input = Int(round(Double(totalTokens) * (Double(snapshotUsage.input) / Double(snapTotal))))
        let cache = Int(round(Double(totalTokens) * (Double(snapshotUsage.cachedInput) / Double(snapTotal))))
        let output = max(0, totalTokens - input - cache)
        return TokenUsage(input: input, cachedInput: cache, output: output, reasoning: snapshotUsage.reasoning)
    }

    /// 计算指定分桶集合与当前选中下钻桶的核心看板摘要
    func calculateSummary(
        buckets: [TokenDistributionBucket],
        selectedBucket: TokenDistributionBucket?,
        pricing: PricingPreferences
    ) -> MonitoringOverviewSummary {
        // 如果当前有下钻选中某一柱子，则指标卡展示该柱子的专项数据
        if let selected = selectedBucket {
            let totalTokens = selected.totalTokens

            // 与前一个柱子计算环比变化率
            var delta: Double? = nil
            if let idx = buckets.firstIndex(where: { $0.id == selected.id }), idx > 0 {
                let prev = buckets[idx - 1].totalTokens
                if prev > 0 {
                    delta = Double(totalTokens - prev) / Double(prev)
                }
            }

            let totalCached = selected.providerBreakdown.reduce(0) { $0 + $1.cachedTokens }
            let totalInput = selected.providerBreakdown.reduce(0) { $0 + $1.inputTokens }
            let hitRate = (totalInput + totalCached) > 0 ? Double(totalCached) / Double(totalInput + totalCached) : 0.0

            let totalCost = selected.providerBreakdown.reduce(0.0) { $0 + $1.estimatedCost }
            let totalRequests = selected.providerBreakdown.reduce(0) { $0 + $1.requestsCount }

            // 计算节省金额（按 80% 节省基准估算）
            let cacheSavings = (Double(totalCached) / 1_000_000.0) * 2.0 * (pricing.targetCurrency == .cny ? pricing.usdToCnyRate : 1.0)
            let formattedSavings = String(format: "%@%.2f", pricing.targetCurrency.symbol, cacheSavings)

            return MonitoringOverviewSummary(
                totalTokens: totalTokens,
                tokensDeltaRatio: delta,
                cacheHitRate: hitRate,
                cacheSavingsDisplay: formattedSavings,
                totalEstimatedCost: totalCost,
                totalRequestsCount: totalRequests
            )
        }

        // 默认全局概览汇总：汇总所有柱子
        let totalTokens = buckets.reduce(0) { $0 + $1.totalTokens }

        // 计算最后一桶与倒数第二桶的环比变化
        var delta: Double? = nil
        if buckets.count >= 2 {
            let last = buckets[buckets.count - 1].totalTokens
            let prev = buckets[buckets.count - 2].totalTokens
            if prev > 0 {
                delta = Double(last - prev) / Double(prev)
            }
        }

        var totalCached = 0
        var totalInput = 0
        var totalCost = 0.0
        var totalRequests = 0

        for b in buckets {
            for item in b.providerBreakdown {
                totalCached += item.cachedTokens
                totalInput += item.inputTokens
                totalCost += item.estimatedCost
                totalRequests += item.requestsCount
            }
        }

        let hitRate = (totalInput + totalCached) > 0 ? Double(totalCached) / Double(totalInput + totalCached) : 0.0
        let cacheSavings = (Double(totalCached) / 1_000_000.0) * 2.0 * (pricing.targetCurrency == .cny ? pricing.usdToCnyRate : 1.0)
        let formattedSavings = String(format: "%@%.2f", pricing.targetCurrency.symbol, cacheSavings)

        return MonitoringOverviewSummary(
            totalTokens: totalTokens,
            tokensDeltaRatio: delta,
            cacheHitRate: hitRate,
            cacheSavingsDisplay: formattedSavings,
            totalEstimatedCost: totalCost,
            totalRequestsCount: totalRequests
        )
    }
}
