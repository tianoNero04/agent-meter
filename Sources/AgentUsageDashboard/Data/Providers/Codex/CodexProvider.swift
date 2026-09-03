import Foundation

/// Codex 适配器：本机会话采集器（本地通道）和官方 API 客户端（账号通道）解耦。
/// 账号额度仿照 cc-switch 优先通过直接 HTTPS 调用官方接口获取，避免子进程阻塞；失败时降级回 app-server。
/// 账号查询失败时沿用上一份账号窗口和账号 Token，并保留错误信息。
struct CodexProvider: UsageProviderAdapter {
    let provider: Provider = .codex

    private let collector: CodexSessionCollector
    private let appServerClient: CodexAppServerClient
    private let directApiClient: CodexDirectApiClient

    init(
        collector: CodexSessionCollector = CodexSessionCollector(),
        appServerClient: CodexAppServerClient = CodexAppServerClient(),
        directApiClient: CodexDirectApiClient? = nil
    ) {
        self.collector = collector
        self.appServerClient = appServerClient
        self.directApiClient = directApiClient ?? CodexDirectApiClient(
            homeURL: collector.homeURL,
            allowKeychain: collector.homeURL.path == FileManager.default.homeDirectoryForCurrentUser.path
        )
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

    /// 账号通道：仿照 cc-switch 优先采用直接 HTTPS 接口读取实时额度（无子进程开销）；若未配置或失败则降级到 app-server 兜底
    private func refreshAccount(previous: ProviderSnapshot) async -> ProviderSnapshot {
        var accountData: CodexAccountData?
        var accountError: Error?
        var usedSource = "direct-api + session-jsonl"

        do {
            accountData = try await directApiClient.fetch()
        } catch {
            // 直连 API 失败（未找到凭据、网络不通等），平滑降级调用 app-server 兜底
            do {
                accountData = try await appServerClient.fetch()
                usedSource = "app-server + session-jsonl"
            } catch {
                accountError = error
            }
        }

        return ProviderSnapshot(
            provider: .codex,
            status: accountData != nil ? .connected : previous.status,
            account: accountData?.account ?? previous.account,
            windows: accountData?.windows.isEmpty == false
                ? accountData!.windows
                : previous.windows,
            accountUsage: accountData?.usage ?? previous.accountUsage,
            localTokenUsage: previous.localTokenUsage,
            localDailyBuckets: previous.localDailyBuckets,
            localModels: previous.localModels,
            source: accountData != nil ? usedSource : previous.source,
            collectedAt: Date(),
            errorMessage: accountError?.localizedDescription
        )
    }

    /// 本地通道：从本地日志解析统计 Token 与 7 日分桶，额度窗口沿用上一份快照。
    private func refreshLocal(previous: ProviderSnapshot) async -> ProviderSnapshot {
        let local = await Task.detached(priority: .utility) { [collector] in
            collector.collect()
        }.value

        let status: ProviderStatus = !local.models.isEmpty ? .connected : previous.status
        return ProviderSnapshot(
            provider: .codex,
            status: status,
            account: previous.account,
            windows: previous.windows,
            accountUsage: previous.accountUsage,
            localTokenUsage: local.tokenUsage,
            localDailyBuckets: !local.dailyBuckets.isEmpty ? local.dailyBuckets : previous.localDailyBuckets,
            localModels: local.models,
            source: previous.source == "none" ? "session-jsonl" : previous.source,
            collectedAt: Date(),
            errorMessage: nil
        )
    }
}
