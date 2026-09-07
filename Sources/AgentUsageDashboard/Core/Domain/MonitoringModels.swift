import Foundation

/// 监控大盘时间统计粒度
enum TimeGranularity: String, CaseIterable, Identifiable, Sendable {
    case daily = "日"
    case weekly = "周"
    case monthly = "月"

    var id: String { rawValue }
}

/// 单个模型提供商在指定时段内的下钻细分统计项
struct ProviderBreakdownItem: Identifiable, Hashable, Sendable {
    var id: String { provider.rawValue }

    /// 提供商类型（Codex / Kimi）
    let provider: Provider
    /// 展示名称（如 "Codex CLI & App Server", "Kimi Code"）
    let displayName: String
    /// 徽标标签（如 "CODEX", "KIMI"）
    let badgeText: String
    /// 估算会话或交互次数
    let requestsCount: Int
    /// 普通输入 Token 数
    let inputTokens: Int
    /// Prompt 缓存命中读取 Token 数
    let cachedTokens: Int
    /// 模型输出/推理 Token 数
    let outputTokens: Int
    /// 该提供商在当前时段的总 Token 消耗
    let totalTokens: Int
    /// 占当前时段总消耗的百分比（0.0 ~ 1.0）
    let shareRatio: Double
    /// 预估法币花费金额
    let estimatedCost: Double

    init(
        provider: Provider,
        displayName: String,
        badgeText: String,
        requestsCount: Int,
        inputTokens: Int,
        cachedTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        shareRatio: Double,
        estimatedCost: Double
    ) {
        self.provider = provider
        self.displayName = displayName
        self.badgeText = badgeText
        self.requestsCount = requestsCount
        self.inputTokens = inputTokens
        self.cachedTokens = cachedTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.shareRatio = shareRatio
        self.estimatedCost = estimatedCost
    }
}

/// 柱状图统计分桶（单个柱子代表的时间单元）
struct TokenDistributionBucket: Identifiable, Hashable, Sendable {
    var id: String { label }

    /// 分桶起始时间
    let startDate: Date
    /// 分桶 X 轴简要标签（如 "09/01", "W36", "9月"）
    let label: String
    /// 完整时间范围描述（如 "2026-09-01 (周二)"）
    let fullDescription: String
    /// 该桶消耗的 Token 总量
    let totalTokens: Int
    /// Codex 消耗的 Token 数
    let codexTokens: Int
    /// Kimi 消耗的 Token 数
    let kimiTokens: Int
    /// 该桶各提供商的下钻细分列表
    let providerBreakdown: [ProviderBreakdownItem]

    init(
        startDate: Date,
        label: String,
        fullDescription: String,
        totalTokens: Int,
        codexTokens: Int,
        kimiTokens: Int,
        providerBreakdown: [ProviderBreakdownItem] = []
    ) {
        self.startDate = startDate
        self.label = label
        self.fullDescription = fullDescription
        self.totalTokens = totalTokens
        self.codexTokens = codexTokens
        self.kimiTokens = kimiTokens
        self.providerBreakdown = providerBreakdown
    }
}

/// 监控大盘顶部核心指标看板概要
struct MonitoringOverviewSummary: Hashable, Sendable {
    /// 当前所选时段的总消耗 Token 数
    let totalTokens: Int
    /// 环比变化率（例如 +0.064 表示增长 6.4%，负数表示下降）
    let tokensDeltaRatio: Double?
    /// 缓存读取命中率（0.0 ~ 1.0）
    let cacheHitRate: Double
    /// Prompt 缓存节省的法币预估（格式化文本，如 "$1.28"）
    let cacheSavingsDisplay: String
    /// 预估总法币花费金额
    let totalEstimatedCost: Double
    /// 预估交互/请求总数
    let totalRequestsCount: Int

    init(
        totalTokens: Int,
        tokensDeltaRatio: Double?,
        cacheHitRate: Double,
        cacheSavingsDisplay: String,
        totalEstimatedCost: Double,
        totalRequestsCount: Int
    ) {
        self.totalTokens = totalTokens
        self.tokensDeltaRatio = tokensDeltaRatio
        self.cacheHitRate = cacheHitRate
        self.cacheSavingsDisplay = cacheSavingsDisplay
        self.totalEstimatedCost = totalEstimatedCost
        self.totalRequestsCount = totalRequestsCount
    }
}
