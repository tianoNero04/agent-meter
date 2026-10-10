import XCTest
@testable import AgentUsageDashboardKit

final class PricingProviderClassifierTests: XCTestCase {
    func testClassifiesGeminiModelsAsGoogle() {
        XCTAssertEqual(PricingProviderClassifier.providerName(for: "gemini-2.5-pro"), "Google")
        XCTAssertEqual(PricingProviderClassifier.providerName(for: "google/gemini-2.5-flash"), "Google")
    }

    func testKeepsExistingProviderMappings() {
        XCTAssertEqual(PricingProviderClassifier.providerName(for: "gpt-5.6-luna"), "OpenAI")
        XCTAssertEqual(PricingProviderClassifier.providerName(for: "claude-sonnet-4"), "Anthropic")
        XCTAssertEqual(PricingProviderClassifier.providerName(for: "unknown-model"), "通用")
    }
}
