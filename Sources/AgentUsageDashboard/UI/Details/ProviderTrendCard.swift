import SwiftUI
import Charts

struct ProviderTrendCard: View {
    let snapshot: ProviderSnapshot
    private var buckets: [DailyTokenBucket] { recentSevenDayBuckets(snapshot.provider == .codex ? (snapshot.accountUsage?.dailyBuckets ?? []) : snapshot.localDailyBuckets) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(snapshot.provider.displayName).font(.headline)
            if !buckets.isEmpty {
                Chart(buckets) { bucket in
                    BarMark(x: .value("日期", bucket.startDate, unit: .day), y: .value("Token", bucket.tokens)).foregroundStyle(snapshot.provider == .codex ? Color.blue : Color.purple)
                }
                .frame(height: 180)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis").font(.title2).foregroundStyle(.secondary)
                    Text("暂无账号趋势").foregroundStyle(.secondary)
                    Text("平台未提供或尚未完成采集").font(.caption).foregroundStyle(.secondary)
                }
                .frame(height: 160).frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}
