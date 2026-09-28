import Foundation

/// Antigravity 适配器：本机会话采集器（本地通道）和官方 API 直连客户端（账号通道）解耦。
/// 账号额度通过直接 HTTPS 调用 Google Cloud Code 官方内部接口获取，支持自动静默刷新与 Claude/Gemini 核心配额解析；
/// 本机统计从 ~/.antigravity_tools/token_stats.db 采集模型排行与 7 日动态趋势；
/// 账号查询失败时沿用上一份可用数据并保留错误信息。
struct AntigravityProvider: UsageProviderAdapter {
    let provider: Provider = .antigravity

    private let collector: AntigravitySessionCollector
    private let directApiClient: AntigravityDirectApiClient

    init(
        collector: AntigravitySessionCollector = AntigravitySessionCollector(),
        directApiClient: AntigravityDirectApiClient? = nil
    ) {
        self.collector = collector
        self.directApiClient = directApiClient ?? AntigravityDirectApiClient(homeURL: collector.homeURL)
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

    /// 账号通道：直接请求 Google Cloud Code 额度接口，本机统计字段沿用上一份快照。
    private func refreshAccount(previous: ProviderSnapshot) async -> ProviderSnapshot {
        var accountData: AntigravityAccountData?
        var accountError: Error?

        do {
            accountData = try await directApiClient.fetch()
        } catch {
            accountError = error
        }

        return ProviderSnapshot(
            provider: .antigravity,
            status: accountData != nil ? .connected : previous.status,
            account: accountData?.account ?? previous.account,
            windows: accountData?.windows.isEmpty == false
                ? accountData!.windows
                : previous.windows,
            accountUsage: previous.accountUsage,
            localTokenUsage: previous.localTokenUsage,
            localDailyBuckets: previous.localDailyBuckets,
            localModels: previous.localModels,
            source: accountData != nil ? "direct-api + token-stats" : previous.source,
            collectedAt: Date(),
            errorMessage: accountError?.localizedDescription
        )
    }

    /// 本地通道：从 token_stats.db 解析本机会话统计，额度窗口优先沿用上一份快照或本地配额缓存。
    private func refreshLocal(previous: ProviderSnapshot) async -> ProviderSnapshot {
        let local = await Task.detached(priority: .utility) { [collector] in
            collector.collect()
        }.value

        let cachedAccountData = directApiClient.readLocalCachedAccountData()
        let resolvedAccount = previous.account ?? cachedAccountData?.account
        let resolvedWindows = !previous.windows.isEmpty ? previous.windows : (cachedAccountData?.windows ?? [])

        let hasData = !local.models.isEmpty || !resolvedWindows.isEmpty || resolvedAccount != nil
        let status: ProviderStatus = hasData ? .connected : previous.status
        return ProviderSnapshot(
            provider: .antigravity,
            status: status,
            account: resolvedAccount,
            windows: resolvedWindows,
            accountUsage: previous.accountUsage,
            localTokenUsage: local.tokenUsage,
            localDailyBuckets: local.dailyBuckets,
            localModels: local.models,
            source: previous.source == "none" ? "token-stats" : previous.source,
            collectedAt: Date(),
            errorMessage: nil
        )
    }
}
