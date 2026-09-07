import XCTest
@testable import AgentUsageDashboardKit

final class MonitoringAggregatorTests: XCTestCase {
    private var calendar: Calendar!
    private var fixedNow: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 7
        components.hour = 12
        fixedNow = calendar.date(from: components)!
    }

    func testAggregateDailyBucketsGeneratesSevenBuckets() {
        let aggregator = MonitoringAggregator(calendar: calendar, now: fixedNow)
        let pricing = PricingPreferences()

        // 构造带有固定日期的本地分桶
        let day1 = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: fixedNow))!
        let day2 = calendar.date(byAdding: .day, value: 0, to: calendar.startOfDay(for: fixedNow))!

        let codexSnapshot = ProviderSnapshot(
            provider: .codex,
            status: .connected,
            account: nil,
            windows: [],
            accountUsage: nil,
            localTokenUsage: TokenUsage(input: 10000, cachedInput: 5000, output: 2000),
            localDailyBuckets: [
                DailyTokenBucket(startDate: day1, tokens: 10000),
                DailyTokenBucket(startDate: day2, tokens: 25000)
            ],
            localModels: [],
            source: "test",
            collectedAt: fixedNow,
            errorMessage: nil
        )

        let kimiSnapshot = ProviderSnapshot(
            provider: .kimiCode,
            status: .connected,
            account: nil,
            windows: [],
            accountUsage: nil,
            localTokenUsage: TokenUsage(input: 4000, cachedInput: 2000, output: 1000),
            localDailyBuckets: [
                DailyTokenBucket(startDate: day2, tokens: 15000)
            ],
            localModels: [],
            source: "test",
            collectedAt: fixedNow,
            errorMessage: nil
        )

        let buckets = aggregator.aggregateBuckets(
            codex: codexSnapshot,
            kimi: kimiSnapshot,
            granularity: .daily,
            pricing: pricing
        )

        XCTAssertEqual(buckets.count, 7, "应当生成最近 7 天的每日分桶")

        // 验证今天的桶（最后一桶）
        let todayBucket = buckets.last!
        XCTAssertEqual(todayBucket.totalTokens, 40000, "今天 Token 总数应为 Codex(25000) + Kimi(15000)")
        XCTAssertEqual(todayBucket.codexTokens, 25000)
        XCTAssertEqual(todayBucket.kimiTokens, 15000)
        XCTAssertEqual(todayBucket.providerBreakdown.count, 2, "应拆分为 Codex 与 Kimi 两个提供商下钻项")

        let codexItem = todayBucket.providerBreakdown.first(where: { $0.provider == Provider.codex })!
        XCTAssertEqual(codexItem.shareRatio, 25000.0 / 40000.0, accuracy: 0.001)

        // 验证指标计算
        let summary = aggregator.calculateSummary(buckets: buckets, selectedBucket: nil, pricing: pricing)
        XCTAssertEqual(summary.totalTokens, 50000, "全局汇总应为昨天 10000 + 今天 40000 = 50000")
        XCTAssertNotNil(summary.tokensDeltaRatio)
        XCTAssertTrue(summary.tokensDeltaRatio! > 0, "今天(40000)比昨天(10000)环比增加")
    }

    func testDrilldownSummaryCalculatesForSelectedBucket() {
        let aggregator = MonitoringAggregator(calendar: calendar, now: fixedNow)
        let pricing = PricingPreferences()

        let day0 = calendar.startOfDay(for: fixedNow)
        let codexSnapshot = ProviderSnapshot(
            provider: .codex,
            status: .connected,
            account: nil,
            windows: [],
            accountUsage: nil,
            localTokenUsage: TokenUsage(input: 20000, cachedInput: 10000, output: 5000),
            localDailyBuckets: [DailyTokenBucket(startDate: day0, tokens: 35000)],
            localModels: [],
            source: "test",
            collectedAt: fixedNow,
            errorMessage: nil
        )

        let buckets = aggregator.aggregateBuckets(
            codex: codexSnapshot,
            kimi: .empty(.kimiCode),
            granularity: .daily,
            pricing: pricing
        )

        let selected = buckets.last!
        let drilldownSummary = aggregator.calculateSummary(buckets: buckets, selectedBucket: selected, pricing: pricing)

        XCTAssertEqual(drilldownSummary.totalTokens, 35000)
        XCTAssertTrue(drilldownSummary.cacheHitRate > 0)
    }

    func testWeeklyAndMonthlyAggregations() {
        let aggregator = MonitoringAggregator(calendar: calendar, now: fixedNow)
        let pricing = PricingPreferences()

        let weeklyBuckets = aggregator.aggregateBuckets(
            codex: .empty(.codex),
            kimi: .empty(.kimiCode),
            granularity: .weekly,
            pricing: pricing
        )
        XCTAssertEqual(weeklyBuckets.count, 4, "周粒度应聚合 4 周")

        let monthlyBuckets = aggregator.aggregateBuckets(
            codex: .empty(.codex),
            kimi: .empty(.kimiCode),
            granularity: .monthly,
            pricing: pricing
        )
        XCTAssertEqual(monthlyBuckets.count, 3, "月粒度应聚合 3 个月")
    }
}
