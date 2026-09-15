import Foundation

/// 在线模型定价同步错误定义
enum ModelPricingSyncError: LocalizedError {
    case invalidURL
    case networkFailure(String)
    case invalidResponse(Int)
    case parsingFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "定价同步服务的 URL 无效"
        case .networkFailure(let reason):
            return "网络连接失败: \(reason)"
        case .invalidResponse(let statusCode):
            return "定价服务返回异常 HTTP 状态码: \(statusCode)"
        case .parsingFailure(let reason):
            return "模型费率数据解析失败: \(reason)"
        }
    }
}

/// 负责从官方与社区权威定价源（models.dev）拉取并同步最新模型费率的数据服务
/// 遵循 AGENTS.md 规范：零常驻网络，仅在按需触发时通过短超时 URLSession 执行单次请求
final class ModelPricingSyncService: Sendable {
    static let shared = ModelPricingSyncService()

    /// 官方 API 端点（对齐 cc-switch modelsDevPricing）
    static let defaultEndpoint = "https://models.dev/api.json"

    private let endpoint: String
    private let session: URLSession

    /// 核心关心的主流 AI 提供商标示
    private static let targetProviders: Set<String> = [
        "openai",
        "moonshotai",
        "moonshotai-cn",
        "kimi-for-coding",
        "anthropic",
        "deepseek",
        "xai",
        "google"
    ]

    init(
        endpoint: String = ModelPricingSyncService.defaultEndpoint,
        session: URLSession? = nil
    ) {
        self.endpoint = endpoint
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 6.0
            config.timeoutIntervalForResource = 8.0
            self.session = URLSession(configuration: config)
        }
    }

    /// 从 models.dev 真实拉取全量最新模型单价矩阵
    func fetchLatestPricings() async throws -> [ModelPricing] {
        guard let url = URL(string: endpoint) else {
            throw ModelPricingSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("AgentMeter/1.0 (Macintosh; Apple Silicon)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ModelPricingSyncError.networkFailure(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelPricingSyncError.invalidResponse(-1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ModelPricingSyncError.invalidResponse(httpResponse.statusCode)
        }

        return try parseModels(from: data)
    }

    /// 将远端最新定价合并到本地偏好并完成持久化
    func syncAndSave(store: PricingSettingsStore) async throws -> (updatedCount: Int, totalCount: Int) {
        let fetchedPricings = try await fetchLatestPricings()
        var preferences = store.load()

        var updated = 0
        for item in fetchedPricings {
            let key = item.modelName.lowercased()
            // 如果不存在或价格有差异，更新它
            if preferences.customPricings[key] != item {
                preferences.customPricings[key] = item
                updated += 1
            }

            // 同时也保存组织别名版本（如 kimi-code/k3-256k）
            let normalized = DefaultModelPricings.normalizeModelName(key)
            if normalized != key && preferences.customPricings[normalized] != item {
                var normalizedItem = item
                normalizedItem.modelName = normalized
                preferences.customPricings[normalized] = normalizedItem
            }
        }

        store.save(preferences)
        return (updated, fetchedPricings.count)
    }

    /// 解析 models.dev 的 JSON 字典结构
    func parseModels(from data: Data) throws -> [ModelPricing] {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ModelPricingSyncError.parsingFailure("无法将返回数据反序列化为 JSON 字典")
        }

        var results: [ModelPricing] = []

        for (providerKey, providerVal) in jsonObject {
            guard let providerDict = providerVal as? [String: Any],
                  let modelsDict = providerDict["models"] as? [String: Any] else {
                continue
            }

            let isTarget = Self.targetProviders.contains(providerKey.lowercased())
            if !isTarget { continue }

            for (modelId, modelVal) in modelsDict {
                guard let modelInfo = modelVal as? [String: Any],
                      let cost = modelInfo["cost"] as? [String: Any] else {
                    continue
                }

                // 读取 input, output, cache_read
                let input = parseCostValue(cost["input"])
                let output = parseCostValue(cost["output"])
                let cacheRead = parseCostValue(cost["cache_read"])

                // 只有至少配置了 input 或 output 的模型才计入
                guard input > 0 || output > 0 else { continue }

                let pricing = ModelPricing(
                    modelName: modelId,
                    inputPerMillion: input,
                    cacheReadPerMillion: cacheRead,
                    outputPerMillion: output,
                    baseCurrency: .usd
                )
                results.append(pricing)
            }
        }

        return results
    }

    private func parseCostValue(_ value: Any?) -> Double {
        if let d = value as? Double {
            return d
        }
        if let i = value as? Int {
            return Double(i)
        }
        if let s = value as? String, let parsed = Double(s) {
            return parsed
        }
        return 0.0
    }
}
