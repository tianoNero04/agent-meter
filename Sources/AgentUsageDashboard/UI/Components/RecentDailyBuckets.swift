import Foundation

/// 过滤最近 7 天内的 Token 分桶（以本地当前时间为基准，包含近 7 天历史至今天结束）
func recentSevenDayBuckets(_ buckets: [DailyTokenBucket], now: Date = .now) -> [DailyTokenBucket] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)
    guard let cutoff = calendar.date(byAdding: .day, value: -6, to: today),
          let endOfToday = calendar.date(byAdding: .day, value: 1, to: today) else {
        return buckets
    }
    return buckets.filter { $0.startDate >= cutoff && $0.startDate < endOfToday }
}
