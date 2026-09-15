import XCTest
@testable import AgentUsageDashboardKit

final class ModelPricingSyncServiceTests: XCTestCase {

    func testParseModelsExtractsTargetProviders() throws {
        let sampleJSON = """
        {
            "openai": {
                "name": "OpenAI",
                "models": {
                    "gpt-5.6-luna": {
                        "name": "GPT-5.6 Luna",
                        "cost": {
                            "input": 0.2,
                            "cache_read": 0.02,
                            "output": 1.2
                        }
                    },
                    "gpt-5.5": {
                        "name": "GPT-5.5",
                        "cost": {
                            "input": 5.0,
                            "cache_read": 0.5,
                            "output": 30.0
                        }
                    }
                }
            },
            "kimi-for-coding": {
                "name": "Kimi Code",
                "models": {
                    "k3-256k": {
                        "name": "Kimi K3 256k",
                        "cost": {
                            "input": 3.0,
                            "cache_read": 0.3,
                            "output": 15.0
                        }
                    }
                }
            },
            "irrelevant-provider": {
                "name": "Other",
                "models": {
                    "other-model": {
                        "cost": {
                            "input": 1.0,
                            "output": 2.0
                        }
                    }
                }
            }
        }
        """

        let data = sampleJSON.data(using: .utf8)!
        let service = ModelPricingSyncService()
        let pricings = try service.parseModels(from: data)

        XCTAssertEqual(pricings.count, 3, "应只抽取目标主流厂商的模型")

        let luna = pricings.first(where: { $0.modelName == "gpt-5.6-luna" })
        XCTAssertNotNil(luna)
        XCTAssertEqual(luna?.inputPerMillion, 0.2)
        XCTAssertEqual(luna?.cacheReadPerMillion, 0.02)
        XCTAssertEqual(luna?.outputPerMillion, 1.2)

        let k3 = pricings.first(where: { $0.modelName == "k3-256k" })
        XCTAssertNotNil(k3)
        XCTAssertEqual(k3?.inputPerMillion, 3.0)
    }

    func testParseModelsThrowsOnCorruptedJSON() {
        let badData = "Not JSON".data(using: .utf8)!
        let service = ModelPricingSyncService()

        XCTAssertThrowsError(try service.parseModels(from: badData)) { error in
            guard let syncError = error as? ModelPricingSyncError,
                  case .parsingFailure = syncError else {
                XCTFail("应抛出 parsingFailure 错误")
                return
            }
        }
    }

    func testSyncAndSaveMergesAndPersists() async throws {
        // 创建内存 Mock Store
        final class FakePricingStore: PricingSettingsStore, @unchecked Sendable {
            var prefs = PricingPreferences()
            func load() -> PricingPreferences { prefs }
            func save(_ preferences: PricingPreferences) { self.prefs = preferences }
        }

        let store = FakePricingStore()

        // 构造自定义 URLProtocol 支持模拟 HTTP 响应
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let mockResponseJSON = """
        {
            "openai": {
                "models": {
                    "gpt-5.6-luna": {
                        "cost": { "input": 0.2, "cache_read": 0.02, "output": 1.2 }
                    }
                }
            }
        }
        """
        MockURLProtocol.stubResponseData = mockResponseJSON.data(using: .utf8)
        MockURLProtocol.stubStatusCode = 200

        let service = ModelPricingSyncService(endpoint: "https://test.models.dev/api.json", session: session)
        let result = try await service.syncAndSave(store: store)

        XCTAssertEqual(result.totalCount, 1)
        XCTAssertEqual(store.prefs.customPricings["gpt-5.6-luna"]?.inputPerMillion, 0.2)
    }
}

/// 专用于单元测试的轻量 URLProtocol 模拟桩
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var stubResponseData: Data?
    nonisolated(unsafe) static var stubStatusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let data = Self.stubResponseData,
           let url = request.url,
           let response = HTTPURLResponse(url: url, statusCode: Self.stubStatusCode, httpVersion: nil, headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
