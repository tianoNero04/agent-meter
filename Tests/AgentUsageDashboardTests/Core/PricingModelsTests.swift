import XCTest
@testable import AgentUsageDashboardKit

final class PricingModelsTests: XCTestCase {
    func testCalculateCostWithUSDAndCNY() {
        let pricing = ModelPricing(
            modelName: "gpt-4o",
            inputPerMillion: 2.50,
            cacheReadPerMillion: 1.25,
            outputPerMillion: 10.00,
            baseCurrency: .usd
        )

        // 1M 普通输入 + 1M 缓存输入 + 1M 输出
        let usage = TokenUsage(
            input: 1_000_000,
            cachedInput: 1_000_000,
            output: 1_000_000,
            reasoning: 0
        )

        // 美元预期：2.50 + 1.25 + 10.00 = 13.75
        let costUsd = pricing.calculateCost(for: usage, targetCurrency: .usd, exchangeRate: 7.20)
        XCTAssertEqual(costUsd, 13.75, accuracy: 0.001)

        // 人民币预期：13.75 * 7.2 = 99.0
        let costCny = pricing.calculateCost(for: usage, targetCurrency: .cny, exchangeRate: 7.20)
        XCTAssertEqual(costCny, 99.0, accuracy: 0.001)
    }

    func testPromptCachingSavingsCalculation() {
        let pricing = ModelPricing(
            modelName: "claude-3-5-sonnet",
            inputPerMillion: 3.00,
            cacheReadPerMillion: 0.30,
            outputPerMillion: 15.00,
            baseCurrency: .usd
        )

        // 命中 200 万缓存读取 tokens
        let usage = TokenUsage(
            input: 500_000,
            cachedInput: 2_000_000,
            output: 100_000,
            reasoning: 0
        )

        // 节省单价：3.00 - 0.30 = 2.70 每百万
        // 2M tokens 节省：2.70 * 2 = 5.40 USD
        let savingsUsd = pricing.calculateCacheSavings(for: usage, targetCurrency: .usd, exchangeRate: 7.20)
        XCTAssertEqual(savingsUsd, 5.40, accuracy: 0.001)

        // 人民币：5.40 * 7.20 = 38.88 CNY
        let savingsCny = pricing.calculateCacheSavings(for: usage, targetCurrency: .cny, exchangeRate: 7.20)
        XCTAssertEqual(savingsCny, 38.88, accuracy: 0.001)
    }

    func testPricingPreferencesLookupAndFallback() {
        var prefs = PricingPreferences()

        // 匹配内置主流模型
        let gpt4oPricing = prefs.pricing(for: "gpt-4o-2024-08-06")
        XCTAssertEqual(gpt4oPricing.inputPerMillion, 2.50)

        // 匹配自定义模型
        prefs.customPricings["custom-mini"] = ModelPricing(
            modelName: "custom-mini",
            inputPerMillion: 0.50,
            cacheReadPerMillion: 0.10,
            outputPerMillion: 1.00
        )
        let customPricing = prefs.pricing(for: "custom-mini")
        XCTAssertEqual(customPricing.inputPerMillion, 0.50)

        // 未知模型兜底
        let unknownPricing = prefs.pricing(for: "unknown-ai-model-xyz")
        XCTAssertEqual(unknownPricing.modelName, "default")
    }

    func testPricingStoreSaveAndLoadRoundtrip() {
        let suite = "test.pricing.store.\(UUID().uuidString)"
        let store = UserDefaultsPricingSettingsStore(suiteName: suite)

        var prefs = PricingPreferences(targetCurrency: .usd, usdToCnyRate: 7.25)
        prefs.customPricings["my-model"] = ModelPricing(
            modelName: "my-model",
            inputPerMillion: 5.0,
            cacheReadPerMillion: 1.0,
            outputPerMillion: 10.0
        )

        store.save(prefs)

        let loaded = store.load()
        XCTAssertEqual(loaded.targetCurrency, .usd)
        XCTAssertEqual(loaded.usdToCnyRate, 7.25)
        XCTAssertEqual(loaded.customPricings["my-model"]?.inputPerMillion, 5.0)

        UserDefaults.standard.removePersistentDomain(forName: suite)
    }
}
