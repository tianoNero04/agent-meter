import Foundation

func recentSevenDayBuckets(_ buckets: [DailyTokenBucket], now: Date = .now) -> [DailyTokenBucket] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)
    guard let cutoff = calendar.date(byAdding: .day, value: -6, to: today) else { return buckets }
    return buckets.filter { $0.startDate >= cutoff && $0.startDate <= today }
}
