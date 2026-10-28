#if DEBUG
import SwiftUI

/// 预览专用假数据与依赖，只在 DEBUG 编译，不进 release 包。
private struct PreviewAdapter: UsageProviderAdapter {
    let provider: Provider
    let snapshot: ProviderSnapshot

    func refresh(previous: ProviderSnapshot, includeAccount: Bool) async -> ProviderSnapshot {
        snapshot
    }
}

private struct PreviewRepository: SnapshotRepository {
    func load() -> PersistedDashboard? { nil }
    func save(current: DashboardSnapshot, history: [DashboardSnapshot]) {}
}

private struct PreviewSettingsStore: ProviderSettingsStore {
    var preferences = ProviderPreferences()
    func load() -> ProviderPreferences { preferences }
    func save(_ preferences: ProviderPreferences) {}
}

@MainActor
enum PreviewModels {
    static func dashboard(preferences: ProviderPreferences = ProviderPreferences()) -> DashboardModel {
        DashboardModel(
            adapters: [
                PreviewAdapter(provider: .codex, snapshot: codexSnapshot),
                PreviewAdapter(provider: .kimiCode, snapshot: kimiSnapshot)
            ],
            repository: PreviewRepository(),
            settingsStore: PreviewSettingsStore(preferences: preferences),
            watcherFactory: { _ in [] }
        )
    }

    static let codexSnapshot = ProviderSnapshot(
        provider: .codex,
        status: .connected,
        account: AccountIdentity(planType: "plus", email: nil),
        windows: [
            RateLimitWindow(
                id: "codex.primary",
                usedPercent: 34,
                windowMinutes: 300,
                resetsAt: Date().addingTimeInterval(6 * 3600 + 20 * 60)
            ),
            RateLimitWindow(
                id: "codex.secondary",
                usedPercent: 58,
                windowMinutes: 10080,
                resetsAt: Date().addingTimeInterval(6 * 86400 + 20 * 3600)
            )
        ],
        accountUsage: AccountTokenUsage(lifetimeTokens: 210_000, peakDailyTokens: nil, dailyBuckets: nil),
        localTokenUsage: TokenUsage(input: 120_000, cachedInput: 40_000, output: 42_000, reasoning: 8_000),
        localModels: [],
        source: "app-server + session-jsonl",
        collectedAt: Date(),
        errorMessage: nil
    )

    static let kimiSnapshot = ProviderSnapshot(
        provider: .kimiCode,
        status: .connected,
        account: nil,
        windows: [],
        accountUsage: nil,
        localTokenUsage: TokenUsage(input: 80_000, cachedInput: 20_000, output: 30_000, reasoning: 0),
        localDailyBuckets: [],
        localModels: [],
        source: "wire-jsonl",
        collectedAt: Date(),
        errorMessage: nil
    )
}

#Preview("菜单栏弹窗") {
    PopoverView(model: PreviewModels.dashboard())
        .frame(width: 390, height: 425)
}

#Preview("弹窗 · 长账号与刷新错误") {
    var snapshot = PreviewModels.codexSnapshot
    snapshot.account = AccountIdentity(
        planType: "professional-workspace",
        email: "developer-with-a-long-address@example.com"
    )
    snapshot.errorMessage = "账号接口暂时不可用，已保留上一次成功查询的额度数据"
    return ProviderPanel(snapshot: snapshot, isRefreshing: false, lastRefresh: Date(), refresh: {})
        .frame(width: 366, height: 340)
        .padding()
        .background(AppTheme.background)
}

#Preview("额度 · 多窗口与刷新中") {
    var snapshot = PreviewModels.codexSnapshot
    snapshot.windows.append(RateLimitWindow(
        id: "codex.additional",
        usedPercent: 12,
        windowMinutes: 300,
        resetsAt: Date().addingTimeInterval(3600),
        name: "附加模型 · 5 小时"
    ))
    return QuotaCard(snapshot: snapshot, isRefreshing: true, lastRefresh: Date(), refresh: {})
        .frame(width: 366, height: 154)
        .padding()
        .background(AppTheme.background)
}

#Preview("弹窗 · 零可见服务商") {
    let preferences = ProviderPreferences(enabledProviders: [], selectedProvider: nil)
    PopoverView(model: PreviewModels.dashboard(preferences: preferences))
        .frame(width: 390, height: 425)
}

private struct NavBarPreviewHost: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        PopoverTopBar(
            model: PreviewModels.dashboard(),
            selection: .constant(.provider(.codex)),
            openWindow: openWindow,
            onSelect: { _ in }
        )
        .frame(width: 366, height: 48.5)
        .padding()
        .background(Color.black)
    }
}

#Preview("导航栏") {
    NavBarPreviewHost()
}
#endif
