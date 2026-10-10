import Foundation

/// 计费货币币种枚举
enum PricingCurrency: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case usd = "USD"
    case cny = "CNY"

    var id: String { rawValue }

    /// 货币显示符号
    var symbol: String {
        switch self {
        case .usd: return "$"
        case .cny: return "¥"
        }
    }

    /// 货币中文描述
    var displayName: String {
        switch self {
        case .usd: return "美元 (USD $)"
        case .cny: return "人民币 (CNY ¥)"
        }
    }
}

/// 单个模型的官方/自定义三段式 Token 费率（单位：每 100 万 Tokens 的基础法币单价）
struct ModelPricing: Codable, Identifiable, Hashable, Sendable {
    var id: String { modelName.lowercased() }

    /// 模型匹配名称（支持模糊前缀匹配或精准匹配，如 "gpt-4o", "claude-3-5-sonnet"）
    var modelName: String
    /// 普通输入单价（每 1M Tokens）
    var inputPerMillion: Double
    /// Prompt Caching 缓存读取单价（每 1M Tokens，通常比普通输入便宜 80%~90%）
    var cacheReadPerMillion: Double
    /// 模型输出/推理单价（每 1M Tokens）
    var outputPerMillion: Double
    /// 定价使用的原生基准货币（通常官方定价为 USD）
    var baseCurrency: PricingCurrency

    init(
        modelName: String,
        inputPerMillion: Double,
        cacheReadPerMillion: Double,
        outputPerMillion: Double,
        baseCurrency: PricingCurrency = .usd
    ) {
        self.modelName = modelName
        self.inputPerMillion = inputPerMillion
        self.cacheReadPerMillion = cacheReadPerMillion
        self.outputPerMillion = outputPerMillion
        self.baseCurrency = baseCurrency
    }

    /// 计算给定 TokenUsage 的预估费用（已换算为目标货币）
    func calculateCost(for usage: TokenUsage, targetCurrency: PricingCurrency, exchangeRate: Double) -> Double {
        let inputCost = (Double(usage.input) / 1_000_000.0) * inputPerMillion
        let cacheCost = (Double(usage.cachedInput) / 1_000_000.0) * cacheReadPerMillion
        let outputCost = (Double(usage.output + usage.reasoning) / 1_000_000.0) * outputPerMillion
        let baseTotal = inputCost + cacheCost + outputCost

        return convert(amount: baseTotal, from: baseCurrency, to: targetCurrency, exchangeRate: exchangeRate)
    }

    /// 计算通过 Prompt Caching 为用户节省的金额：即 (普通输入单价 - 缓存读取单价) * 缓存命中量
    func calculateCacheSavings(for usage: TokenUsage, targetCurrency: PricingCurrency, exchangeRate: Double) -> Double {
        guard inputPerMillion > cacheReadPerMillion else { return 0.0 }
        let savingPerMillion = inputPerMillion - cacheReadPerMillion
        let baseSavings = (Double(usage.cachedInput) / 1_000_000.0) * savingPerMillion

        return convert(amount: baseSavings, from: baseCurrency, to: targetCurrency, exchangeRate: exchangeRate)
    }

    /// 货币换算辅助方法
    private func convert(amount: Double, from: PricingCurrency, to: PricingCurrency, exchangeRate: Double) -> Double {
        if from == to { return amount }
        if from == .usd && to == .cny {
            return amount * exchangeRate
        }
        if from == .cny && to == .usd {
            return exchangeRate > 0 ? (amount / exchangeRate) : amount
        }
        return amount
    }
}

/// 默认内置的主流模型官方定价预设字典（已对齐 models.dev 2026 年最新官方真实费率，单位：USD/1M Tokens）
enum DefaultModelPricings {
    static let presets: [ModelPricing] = [
        // MARK: - OpenAI Codex 核心旗舰系列
        ModelPricing(modelName: "gpt-5.6-luna", inputPerMillion: 0.20, cacheReadPerMillion: 0.02, outputPerMillion: 1.20),
        ModelPricing(modelName: "gpt-5.6-terra", inputPerMillion: 2.00, cacheReadPerMillion: 0.20, outputPerMillion: 12.00),
        ModelPricing(modelName: "gpt-5.6", inputPerMillion: 4.00, cacheReadPerMillion: 0.40, outputPerMillion: 20.00),
        ModelPricing(modelName: "gpt-5.5", inputPerMillion: 5.00, cacheReadPerMillion: 0.50, outputPerMillion: 30.00),
        ModelPricing(modelName: "gpt-5.4-mini", inputPerMillion: 0.75, cacheReadPerMillion: 0.075, outputPerMillion: 4.50),
        ModelPricing(modelName: "o3-mini", inputPerMillion: 1.10, cacheReadPerMillion: 0.55, outputPerMillion: 4.40),
        ModelPricing(modelName: "o1", inputPerMillion: 15.00, cacheReadPerMillion: 7.50, outputPerMillion: 60.00),
        ModelPricing(modelName: "gpt-4o", inputPerMillion: 2.50, cacheReadPerMillion: 1.25, outputPerMillion: 10.00),
        ModelPricing(modelName: "gpt-4o-mini", inputPerMillion: 0.15, cacheReadPerMillion: 0.075, outputPerMillion: 0.60),

        // MARK: - Kimi (Moonshot AI & Kimi Code 核心系列)
        ModelPricing(modelName: "kimi-k3", inputPerMillion: 3.00, cacheReadPerMillion: 0.30, outputPerMillion: 15.00),
        ModelPricing(modelName: "kimi-k2.7-code", inputPerMillion: 0.95, cacheReadPerMillion: 0.19, outputPerMillion: 4.00),
        ModelPricing(modelName: "kimi-k2.7-code-highspeed", inputPerMillion: 1.90, cacheReadPerMillion: 0.38, outputPerMillion: 8.00),
        ModelPricing(modelName: "moonshot-v1-8k", inputPerMillion: 1.67, cacheReadPerMillion: 0.28, outputPerMillion: 1.67, baseCurrency: .cny),
        ModelPricing(modelName: "moonshot-v1-32k", inputPerMillion: 3.33, cacheReadPerMillion: 0.56, outputPerMillion: 3.33, baseCurrency: .cny),

        // MARK: - Anthropic Claude 系列
        ModelPricing(modelName: "claude-sonnet-4-5", inputPerMillion: 3.00, cacheReadPerMillion: 0.30, outputPerMillion: 15.00),
        ModelPricing(modelName: "claude-3-5-sonnet", inputPerMillion: 3.00, cacheReadPerMillion: 0.30, outputPerMillion: 15.00),
        ModelPricing(modelName: "claude-3-5-haiku", inputPerMillion: 0.80, cacheReadPerMillion: 0.08, outputPerMillion: 4.00),
        ModelPricing(modelName: "claude-3-opus", inputPerMillion: 15.00, cacheReadPerMillion: 1.50, outputPerMillion: 75.00),

        // MARK: - DeepSeek 系列
        ModelPricing(modelName: "deepseek-v4-pro", inputPerMillion: 0.435, cacheReadPerMillion: 0.003625, outputPerMillion: 0.87),
        ModelPricing(modelName: "deepseek-chat", inputPerMillion: 0.14, cacheReadPerMillion: 0.014, outputPerMillion: 0.28),
        ModelPricing(modelName: "deepseek-reasoner", inputPerMillion: 0.55, cacheReadPerMillion: 0.14, outputPerMillion: 2.19),

        // MARK: - xAI 系列
        ModelPricing(modelName: "grok-4.5", inputPerMillion: 2.00, cacheReadPerMillion: 0.30, outputPerMillion: 6.00)
    ]

    /// 兜底未知模型的默认单价（采用温和的 gpt-4o-mini / 轻量级标准估算）
    static let fallback = ModelPricing(
        modelName: "default",
        inputPerMillion: 1.00,
        cacheReadPerMillion: 0.20,
        outputPerMillion: 3.00,
        baseCurrency: .usd
    )

    /// 智能归一化模型标识符，去除组织前缀与常见后缀别名
    static func normalizeModelName(_ rawName: String) -> String {
        var clean = rawName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 去除常见组织前缀
        let prefixes = ["kimi-code/", "openai/", "anthropic/", "deepseek/", "xai/", "google/"]
        for p in prefixes {
            if clean.hasPrefix(p) {
                clean = String(clean.dropFirst(p.count))
                break
            }
        }

        // 2. 映射特定别名到官方模型 ID
        switch clean {
        case "gpt-5.6-sol":
            return "gpt-5.6"
        case "codex-auto-review":
            return "gpt-5.4-mini"
        case "k3-256k", "k3":
            return "kimi-k3"
        case "kimi-for-coding":
            return "kimi-k2.7-code"
        case "kimi-for-coding-highspeed":
            return "kimi-k2.7-code-highspeed"
        default:
            return clean
        }
    }
}

/// 用户全局模型计费偏好设置值对象
struct PricingPreferences: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    /// 持久化结构版本；旧版本中的混合价格表会在存储层升级时丢弃。
    private(set) var schemaVersion: Int
    /// 用户选定的展示币种，默认人民币 CNY
    var targetCurrency: PricingCurrency
    /// 美元对人民币基准参考汇率，默认 7.20
    var usdToCnyRate: Double
    /// 最近一次成功同步得到的官方价格基准（键为规范化 modelName）
    var syncedPricings: [String: ModelPricing]
    /// 用户在本机手动修改的覆盖价格（键为规范化 modelName）
    var customOverrides: [String: ModelPricing]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case targetCurrency
        case usdToCnyRate
        case syncedPricings
        case customOverrides
    }

    init(
        targetCurrency: PricingCurrency = .cny,
        usdToCnyRate: Double = 7.20,
        syncedPricings: [String: ModelPricing] = [:],
        customOverrides: [String: ModelPricing] = [:]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.targetCurrency = targetCurrency
        self.usdToCnyRate = usdToCnyRate
        self.syncedPricings = syncedPricings
        self.customOverrides = customOverrides
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        targetCurrency = try container.decodeIfPresent(PricingCurrency.self, forKey: .targetCurrency) ?? .cny
        usdToCnyRate = try container.decodeIfPresent(Double.self, forKey: .usdToCnyRate) ?? 7.20

        if schemaVersion >= Self.currentSchemaVersion {
            syncedPricings = try container.decodeIfPresent([String: ModelPricing].self, forKey: .syncedPricings) ?? [:]
            customOverrides = try container.decodeIfPresent([String: ModelPricing].self, forKey: .customOverrides) ?? [:]
        } else {
            syncedPricings = [:]
            customOverrides = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(targetCurrency, forKey: .targetCurrency)
        try container.encode(usdToCnyRate, forKey: .usdToCnyRate)
        try container.encode(syncedPricings, forKey: .syncedPricings)
        try container.encode(customOverrides, forKey: .customOverrides)
    }

    /// 旧版本价格表混合了同步数据和本地改价，无法安全区分，因此只保留展示偏好。
    mutating func discardLegacyPricingData() {
        syncedPricings = [:]
        customOverrides = [:]
        schemaVersion = Self.currentSchemaVersion
    }

    /// 规范化同步基准和手动覆盖表中的模型名称。
    mutating func sanitizePricings() {
        syncedPricings = Self.normalizedPricingMap(syncedPricings)
        customOverrides = Self.normalizedPricingMap(customOverrides)
    }

    private static func normalizedPricingMap(_ pricings: [String: ModelPricing]) -> [String: ModelPricing] {
        var cleanMap: [String: ModelPricing] = [:]
        for pricing in pricings.values {
            let canonical = DefaultModelPricings.normalizeModelName(pricing.modelName)
            var normalizedItem = pricing
            normalizedItem.modelName = canonical
            cleanMap[canonical] = normalizedItem
        }
        return cleanMap
    }

    /// 获取特定模型的匹配单价规则（具备智能别名归一化、层级化精准优先与前缀模糊回退）
    func pricing(for modelName: String) -> ModelPricing {
        let cleanName = modelName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = DefaultModelPricings.normalizeModelName(cleanName)

        // 1. 本机手动覆盖优先于任何官方价格
        if let custom = customOverrides[cleanName] ?? customOverrides[normalized] {
            return custom
        }

        // 2. 最近一次成功同步的官方价格
        if let synced = syncedPricings[cleanName] ?? syncedPricings[normalized] {
            return synced
        }

        // 3. 查找内置预设的精确匹配（原名）
        if let preset = DefaultModelPricings.presets.first(where: { $0.modelName.lowercased() == cleanName }) {
            return preset
        }

        // 4. 查找内置预设的归一化名精确匹配
        if let preset = DefaultModelPricings.presets.first(where: { $0.modelName.lowercased() == normalized }) {
            return preset
        }

        // 5. 前缀与包含模糊匹配（优先匹配字符更长、更精准的预设）
        let matches = DefaultModelPricings.presets.filter { preset in
            let pName = preset.modelName.lowercased()
            return cleanName.hasPrefix(pName) ||
                   normalized.hasPrefix(pName) ||
                   pName.hasPrefix(normalized) ||
                   cleanName.contains(pName)
        }
        if let bestMatch = matches.max(by: { $0.modelName.count < $1.modelName.count }) {
            return bestMatch
        }

        // 6. 兜底
        return DefaultModelPricings.fallback
    }
}
