import Foundation

/// Codex adapter：组合本机会话采集器和 App Server 客户端。
/// 账号查询失败时沿用上一份账号窗口和账号 Token，同时更新本机日志统计并保留错误信息。
struct CodexProvider: UsageProviderAdapter {
    let provider: Provider = .codex

    private let collector: CodexSessionCollector
    private let appServerClient: CodexAppServerClient

    init(
        collector: CodexSessionCollector = CodexSessionCollector(),
        appServerClient: CodexAppServerClient = CodexAppServerClient()
    ) {
        self.collector = collector
        self.appServerClient = appServerClient
    }

    func refresh(
        previous: ProviderSnapshot,
        includeAccount: Bool
    ) async -> ProviderSnapshot {
        let local = await Task.detached(priority: .utility) { [collector] in
            collector.collect()
        }.value

        var accountData: CodexAccountData?
        var accountError: Error?
        if includeAccount {
            do {
                accountData = try await appServerClient.fetch()
            } catch {
                accountError = error
            }
        }

        let status: ProviderStatus = accountData != nil || !local.models.isEmpty
            ? .connected
            : previous.status
        return ProviderSnapshot(
            provider: .codex,
            status: status,
            account: accountData?.account ?? previous.account,
            windows: accountData?.windows.isEmpty == false
                ? accountData!.windows
                : (local.windows.isEmpty ? previous.windows : local.windows),
            accountUsage: accountData?.usage ?? previous.accountUsage,
            localTokenUsage: local.tokenUsage,
            localDailyBuckets: previous.localDailyBuckets,
            localModels: local.models,
            source: accountData == nil
                ? (previous.source == "none" ? "session-jsonl" : previous.source)
                : "app-server + session-jsonl",
            collectedAt: Date(),
            errorMessage: accountError?.localizedDescription
        )
    }
}
