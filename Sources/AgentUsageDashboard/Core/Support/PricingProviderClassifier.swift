import Foundation

/// Infers the service provider from a model identifier used by the pricing catalog.
enum PricingProviderClassifier {
    static func providerName(for modelName: String) -> String {
        let clean = modelName.lowercased()
        if clean.contains("gpt") || clean.contains("o1") || clean.contains("o3") || clean.contains("codex") {
            return "OpenAI"
        }
        if clean.contains("kimi") || clean.contains("moonshot") {
            return "Moonshot"
        }
        if clean.contains("claude") {
            return "Anthropic"
        }
        if clean.contains("deepseek") {
            return "DeepSeek"
        }
        if clean.contains("grok") {
            return "xAI"
        }
        if clean.contains("gemini") || clean.contains("gemma") || clean.hasPrefix("google/") || clean.hasPrefix("google-") {
            return "Google"
        }
        return "通用"
    }
}
