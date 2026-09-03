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
    func load() -> ProviderPreferences { ProviderPreferences() }
    func save(_ preferences: ProviderPreferences) {}
}

@MainActor
enum PreviewModels {
    static func dashboard() -> DashboardModel {
        DashboardModel(
            adapters: [
                PreviewAdapter(provider: .codex, snapshot: codexSnapshot),
                PreviewAdapter(provider: .kimiCode, snapshot: kimiSnapshot)
            ],
            repository: PreviewRepository(),
            settingsStore: PreviewSettingsStore(),
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
