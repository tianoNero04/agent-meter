import Foundation

/// Kimi Code adapter：只提供本机会话采集（本地通道）。
/// 官方账号额度接口尚未接入，账号通道是 no-op：原样返回上一份快照，
/// 不解析本地日志，也不制造账号级百分比。
struct KimiProvider: UsageProviderAdapter {
    let provider: Provider = .kimiCode

    private let collector: KimiSessionCollector

    init(collector: KimiSessionCollector = KimiSessionCollector()) {
        self.collector = collector
    }

    func refresh(
        previous: ProviderSnapshot,
        includeAccount: Bool
    ) async -> ProviderSnapshot {
        guard !includeAccount else { return previous }

        let local = await Task.detached(priority: .utility) { [collector] in
            collector.collect()
        }.value

        return ProviderSnapshot(
            provider: .kimiCode,
            status: local.models.isEmpty ? .unavailable : .connected,
            account: nil,
            windows: [],
            accountUsage: nil,
            localTokenUsage: local.tokenUsage,
            localDailyBuckets: local.dailyBuckets,
            localModels: local.models,
            source: "wire-jsonl",
            collectedAt: Date(),
            errorMessage: nil
        )
    }
}
