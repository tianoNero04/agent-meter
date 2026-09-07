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

/// 默认内置的主流模型官方定价预设字典
enum DefaultModelPricings {
    static let presets: [ModelPricing] = [
        // OpenAI 系列
        ModelPricing(modelName: "gpt-4o", inputPerMillion: 2.50, cacheReadPerMillion: 1.25, outputPerMillion: 10.00),
        ModelPricing(modelName: "gpt-4o-mini", inputPerMillion: 0.15, cacheReadPerMillion: 0.075, outputPerMillion: 0.60),
        ModelPricing(modelName: "o3-mini", inputPerMillion: 1.10, cacheReadPerMillion: 0.55, outputPerMillion: 4.40),
        ModelPricing(modelName: "o1", inputPerMillion: 15.00, cacheReadPerMillion: 7.50, outputPerMillion: 60.00),

        // Anthropic Claude 系列
        ModelPricing(modelName: "claude-3-5-sonnet", inputPerMillion: 3.00, cacheReadPerMillion: 0.30, outputPerMillion: 15.00),
        ModelPricing(modelName: "claude-3-5-haiku", inputPerMillion: 0.80, cacheReadPerMillion: 0.08, outputPerMillion: 4.00),
        ModelPricing(modelName: "claude-3-opus", inputPerMillion: 15.00, cacheReadPerMillion: 1.50, outputPerMillion: 75.00),

        // Kimi 系列（按人民币换算官方标准或官方 API 费率）
        ModelPricing(modelName: "moonshot-v1-8k", inputPerMillion: 1.67, cacheReadPerMillion: 0.28, outputPerMillion: 1.67, baseCurrency: .cny),
        ModelPricing(modelName: "moonshot-v1-32k", inputPerMillion: 3.33, cacheReadPerMillion: 0.56, outputPerMillion: 3.33, baseCurrency: .cny),
        ModelPricing(modelName: "kimi-latest", inputPerMillion: 2.00, cacheReadPerMillion: 0.30, outputPerMillion: 2.00, baseCurrency: .cny),

        // DeepSeek 系列
        ModelPricing(modelName: "deepseek-chat", inputPerMillion: 0.14, cacheReadPerMillion: 0.014, outputPerMillion: 0.28),
        ModelPricing(modelName: "deepseek-reasoner", inputPerMillion: 0.55, cacheReadPerMillion: 0.14, outputPerMillion: 2.19)
    ]

    /// 兜底未知模型的默认单价（采用温和的 gpt-4o-mini / 轻量级标准估算）
    static let fallback = ModelPricing(
        modelName: "default",
        inputPerMillion: 1.00,
        cacheReadPerMillion: 0.20,
        outputPerMillion: 3.00,
        baseCurrency: .usd
    )
}

/// 用户全局模型计费偏好设置值对象
struct PricingPreferences: Codable, Equatable, Sendable {
    /// 用户选定的展示币种，默认人民币 CNY
    var targetCurrency: PricingCurrency
    /// 美元对人民币基准参考汇率，默认 7.20
    var usdToCnyRate: Double
    /// 用户自定义或调整后的模型单价映射表（键为小写 modelName）
    var customPricings: [String: ModelPricing]

    init(
        targetCurrency: PricingCurrency = .cny,
        usdToCnyRate: Double = 7.20,
        customPricings: [String: ModelPricing] = [:]
    ) {
        self.targetCurrency = targetCurrency
        self.usdToCnyRate = usdToCnyRate
        self.customPricings = customPricings
    }

    /// 获取特定模型的匹配单价规则（优先用户自定义，其次内置预设，最后兜底）
    func pricing(for modelName: String) -> ModelPricing {
        let cleanName = modelName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 查找精确自定义
        if let custom = customPricings[cleanName] {
            return custom
        }

        // 2. 模糊匹配内置预设
        if let preset = DefaultModelPricings.presets.first(where: { cleanName.contains($0.modelName) || $0.modelName.contains(cleanName) }) {
            return preset
        }

        // 3. 兜底
        return DefaultModelPricings.fallback
    }
}
