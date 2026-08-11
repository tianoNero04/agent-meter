import Foundation

struct ProviderSnapshot: Codable, Identifiable, Hashable {
    var provider: Provider
    var status: ProviderStatus
    var account: AccountIdentity?
    var windows: [RateLimitWindow]
    var accountUsage: AccountTokenUsage?
    var localTokenUsage: TokenUsage
    var localDailyBuckets: [DailyTokenBucket]
    var localModels: [ModelUsage]
    var source: String
    var collectedAt: Date
    var errorMessage: String?

    var id: Provider { provider }

    private enum CodingKeys: String, CodingKey {
        case provider, status, account, windows, accountUsage, localTokenUsage
        case localDailyBuckets, localModels, source, collectedAt, errorMessage
    }

    init(
        provider: Provider,
        status: ProviderStatus,
        account: AccountIdentity?,
        windows: [RateLimitWindow],
        accountUsage: AccountTokenUsage?,
        localTokenUsage: TokenUsage,
        localDailyBuckets: [DailyTokenBucket] = [],
        localModels: [ModelUsage],
        source: String,
        collectedAt: Date,
        errorMessage: String?
    ) {
        self.provider = provider
        self.status = status
        self.account = account
        self.windows = windows
        self.accountUsage = accountUsage
        self.localTokenUsage = localTokenUsage
        self.localDailyBuckets = localDailyBuckets
        self.localModels = localModels
        self.source = source
        self.collectedAt = collectedAt
        self.errorMessage = errorMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(Provider.self, forKey: .provider)
        status = try container.decode(ProviderStatus.self, forKey: .status)
        account = try container.decodeIfPresent(AccountIdentity.self, forKey: .account)
        windows = try container.decode([RateLimitWindow].self, forKey: .windows)
        accountUsage = try container.decodeIfPresent(AccountTokenUsage.self, forKey: .accountUsage)
        localTokenUsage = try container.decode(TokenUsage.self, forKey: .localTokenUsage)
        localDailyBuckets = try container.decodeIfPresent([DailyTokenBucket].self, forKey: .localDailyBuckets) ?? []
        localModels = try container.decode([ModelUsage].self, forKey: .localModels)
        source = try container.decode(String.self, forKey: .source)
        collectedAt = try container.decode(Date.self, forKey: .collectedAt)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(provider, forKey: .provider)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(account, forKey: .account)
        try container.encode(windows, forKey: .windows)
        try container.encodeIfPresent(accountUsage, forKey: .accountUsage)
        try container.encode(localTokenUsage, forKey: .localTokenUsage)
        try container.encode(localDailyBuckets, forKey: .localDailyBuckets)
        try container.encode(localModels, forKey: .localModels)
        try container.encode(source, forKey: .source)
        try container.encode(collectedAt, forKey: .collectedAt)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
    }

    static func empty(_ provider: Provider) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: provider,
            status: .unavailable,
            account: nil,
            windows: [],
            accountUsage: nil,
            localTokenUsage: .zero,
            localDailyBuckets: [],
            localModels: [],
            source: "none",
            collectedAt: .now,
            errorMessage: nil
        )
    }
}

struct DashboardSnapshot: Codable, Hashable {
    var collectedAt: Date
    var providers: [ProviderSnapshot]
}

struct PersistedDashboard: Codable {
    var current: DashboardSnapshot
    var history: [DashboardSnapshot]
}
