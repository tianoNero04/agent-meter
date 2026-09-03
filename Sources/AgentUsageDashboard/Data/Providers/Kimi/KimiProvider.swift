import Foundation

/// Kimi Code 适配器：本机会话采集器（本地通道）和官方 API 直连客户端（账号通道）解耦。
/// 账号额度仿照 Codex 优先通过直接 HTTPS 调用官方 usages 接口获取，支持自动静默刷新与 5小时/周额度解析；
/// 账号查询失败时沿用上一份账号窗口并保留错误信息。
struct KimiProvider: UsageProviderAdapter {
    let provider: Provider = .kimiCode

    private let collector: KimiSessionCollector
    private let directApiClient: KimiDirectApiClient

    init(
        collector: KimiSessionCollector = KimiSessionCollector(),
        directApiClient: KimiDirectApiClient? = nil
    ) {
        self.collector = collector
        self.directApiClient = directApiClient ?? KimiDirectApiClient(homeURL: collector.homeURL)
    }

    func refresh(
        previous: ProviderSnapshot,
        includeAccount: Bool
    ) async -> ProviderSnapshot {
        if includeAccount {
            return await refreshAccount(previous: previous)
        }
        return await refreshLocal(previous: previous)
    }

    /// 账号通道：直接请求 Kimi 官方 usages 接口，本机统计字段沿用上一份快照。
    private func refreshAccount(previous: ProviderSnapshot) async -> ProviderSnapshot {
        var accountData: KimiAccountData?
        var accountError: Error?

        do {
            accountData = try await directApiClient.fetch()
        } catch {
            accountError = error
        }

        return ProviderSnapshot(
            provider: .kimiCode,
            status: accountData != nil ? .connected : previous.status,
            account: accountData?.account ?? previous.account,
            windows: accountData?.windows.isEmpty == false
                ? accountData!.windows
                : previous.windows,
            accountUsage: previous.accountUsage,
            localTokenUsage: previous.localTokenUsage,
            localDailyBuckets: previous.localDailyBuckets,
            localModels: previous.localModels,
            source: accountData != nil ? "direct-api + wire-jsonl" : previous.source,
            collectedAt: Date(),
            errorMessage: accountError?.localizedDescription
        )
    }

    /// 本地通道：从 wire.jsonl 解析本机会话统计，额度窗口沿用上一份快照。
    private func refreshLocal(previous: ProviderSnapshot) async -> ProviderSnapshot {
        let local = await Task.detached(priority: .utility) { [collector] in
            collector.collect()
        }.value

        let status: ProviderStatus = !local.models.isEmpty ? .connected : previous.status
        return ProviderSnapshot(
            provider: .kimiCode,
            status: status,
            account: previous.account,
            windows: previous.windows,
            accountUsage: previous.accountUsage,
            localTokenUsage: local.tokenUsage,
            localDailyBuckets: local.dailyBuckets,
            localModels: local.models,
            source: previous.source == "none" ? "wire-jsonl" : previous.source,
            collectedAt: Date(),
            errorMessage: nil
        )
    }
}
