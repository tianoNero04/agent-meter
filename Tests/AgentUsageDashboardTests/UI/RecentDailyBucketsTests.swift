import XCTest
@testable import AgentUsageDashboardKit

final class RecentDailyBucketsTests: XCTestCase {
    /// 验证近 7 天窗口正确过滤数据，并包含今天全天的数据
    func testRecentSevenDayBucketsIncludesTodayAndPastSixDays() {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: today)!
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let middayToday = calendar.date(byAdding: .hour, value: 12, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let buckets = [
            DailyTokenBucket(startDate: sevenDaysAgo, tokens: 100),
            DailyTokenBucket(startDate: sixDaysAgo, tokens: 200),
            DailyTokenBucket(startDate: today, tokens: 300),
            DailyTokenBucket(startDate: middayToday, tokens: 400),
            DailyTokenBucket(startDate: tomorrow, tokens: 500)
        ]

        let filtered = recentSevenDayBuckets(buckets, now: now)

        // 7天前和明天的数据应当被排除；6天前、今天零点和今天中午的数据应当被保留
        XCTAssertEqual(filtered.count, 3)
        XCTAssertEqual(filtered.map(\.tokens), [200, 300, 400])
    }
}
