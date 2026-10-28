import XCTest
@testable import AgentUsageDashboardKit

final class AntigravityDirectApiClientTests: XCTestCase {
    /// 验证 loadCodeAssist 返回报文的解析（提取 project_id 与当前 tier）
    func testParseLoadCodeAssistExtractsProjectAndTier() throws {
        let jsonString = """
        {
          "cloudaicompanionProject": "aicode-consumers",
          "currentTier": {
            "id": "free-tier",
            "name": "Antigravity Starter Quota"
          }
        }
        """
        let data = jsonString.data(using: .utf8)!
        let (project, tier) = AntigravityDirectApiClient.parseLoadCodeAssist(data: data)

        XCTAssertEqual(project, "aicode-consumers")
        XCTAssertEqual(tier, "free-tier")
        XCTAssertEqual(AntigravityDirectApiClient.normalizeTier(tier), "FREE")
    }

    /// 验证订阅计划标准化逻辑
    func testNormalizeTier() {
        XCTAssertEqual(AntigravityDirectApiClient.normalizeTier("free-tier"), "FREE")
        XCTAssertEqual(AntigravityDirectApiClient.normalizeTier("g1-pro-tier"), "PRO")
        XCTAssertEqual(AntigravityDirectApiClient.normalizeTier("Google AI Pro"), "PRO")
        XCTAssertEqual(AntigravityDirectApiClient.normalizeTier("g1-ultra-tier"), "ULTRA")
        XCTAssertEqual(AntigravityDirectApiClient.normalizeTier("GDP_HELIUM"), "ULTRA")
        XCTAssertEqual(AntigravityDirectApiClient.normalizeTier(nil), "FREE")
        XCTAssertEqual(AntigravityDirectApiClient.normalizeTier("unknown"), "FREE")
    }

    /// 验证 retrieveUserQuotaSummary 响应提取 Claude 与 Gemini 5小时额度窗口
    func testParseQuotaSummaryExtractsClaudeAndGeminiWindows() throws {
        let jsonString = """
        {
          "groups": [
            {
              "displayName": "Gemini Models",
              "buckets": [
                {
                  "bucketId": "gemini-weekly",
                  "window": "weekly",
                  "remainingFraction": 0.95,
                  "resetTime": "2026-10-05T07:38:32Z"
                },
                {
                  "bucketId": "gemini-5h",
                  "window": "5h",
                  "remainingFraction": 0.8,
                  "resetTime": "2026-09-28T12:38:32Z"
                },
                {
                  "bucketId": "gemini-5h-missing-remaining",
                  "window": "5h"
                }
              ]
            },
            {
              "displayName": "Claude and GPT models",
              "buckets": [
                {
                  "bucketId": "3p-weekly",
                  "window": "weekly",
                  "remainingFraction": 1.0,
                  "resetTime": "2026-10-05T07:38:32Z"
                },
                {
                  "bucketId": "3p-5h",
                  "window": "5h",
                  "remainingFraction": 0.45,
                  "resetTime": "2026-09-28T14:00:00Z"
                }
              ]
            }
          ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let windows = AntigravityDirectApiClient.parseQuotaSummary(data: data)

        XCTAssertEqual(windows.count, 4)

        let w5h = try XCTUnwrap(windows.first { $0.id == "antigravity.5h" })
        XCTAssertEqual(w5h.label, "5 小时")
        XCTAssertEqual(w5h.windowMinutes, 300)
        XCTAssertEqual(w5h.usedPercent, 20.0, accuracy: 0.1)

        let wWeekly = try XCTUnwrap(windows.first { $0.id == "antigravity.weekly" })
        XCTAssertEqual(wWeekly.label, "本周")
        XCTAssertEqual(wWeekly.windowMinutes, 10080)
        XCTAssertEqual(wWeekly.usedPercent, 5.0, accuracy: 0.1)

        let claude5h = try XCTUnwrap(windows.first {
            $0.windowMinutes == 300 && $0.id != "antigravity.5h"
        })
        XCTAssertEqual(claude5h.label, "Claude and GPT models · 5 小时")
        XCTAssertEqual(claude5h.usedPercent, 55.0, accuracy: 0.1)

        let claudeWeekly = try XCTUnwrap(windows.first {
            $0.windowMinutes == 10080 && $0.id != "antigravity.weekly"
        })
        XCTAssertEqual(claudeWeekly.label, "Claude and GPT models · 本周")
        XCTAssertEqual(claudeWeekly.usedPercent, 0.0, accuracy: 0.1)
    }

    /// 验证带 go-keyring-base64: 前缀的 Keychain 凭据解析
    func testParseKeyringPayloadWithBase64Prefix() throws {
        let payload = """
        {
          "token": {
            "access_token": "ya29.mock_token_123",
            "refresh_token": "1//mock_refresh_456"
          },
          "email": "user@gmail.com"
        }
        """
        let base64 = payload.data(using: .utf8)!.base64EncodedString()
        let prefixed = "go-keyring-base64:" + base64
        let creds = try AntigravityDirectApiClient.parseKeyringPayload(prefixed.data(using: .utf8)!)

        XCTAssertEqual(creds.accessToken, "ya29.mock_token_123")
        XCTAssertEqual(creds.refreshToken, "1//mock_refresh_456")
        XCTAssertEqual(creds.email, "user@gmail.com")
    }

    /// 验证解析 ~/.antigravity_tools 账户结构
    func testParseToolsAccountJson() {
        let json: [String: Any] = [
            "email": "developer@google.com",
            "token": [
                "access_token": "ya29.tools_token",
                "refresh_token": "1//tools_refresh",
                "project_id": "custom-project"
            ]
        ]
        let creds = AntigravityDirectApiClient.parseToolsAccountJson(json)
        XCTAssertNotNil(creds)
        XCTAssertEqual(creds?.email, "developer@google.com")
        XCTAssertEqual(creds?.accessToken, "ya29.tools_token")
        XCTAssertEqual(creds?.refreshToken, "1//tools_refresh")
        XCTAssertEqual(creds?.projectId, "custom-project")
    }

    /// 验证从 JWT id_token 解码提取 email 字段
    func testParseEmailFromJWT() {
        let header = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = "{\"email\":\"jwt_user@example.com\",\"sub\":\"123456\"}".data(using: .utf8)!.base64EncodedString()
        let jwt = "\(header).\(payload).signature"

        let email = AntigravityDirectApiClient.parseEmailFromJWT(jwt)
        XCTAssertEqual(email, "jwt_user@example.com")
    }

    func testReadLocalCachedAccountDataUsesTemporaryAccountFixture() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("antigravity-cache-\(UUID().uuidString)", isDirectory: true)
        let accounts = root.appendingPathComponent(".antigravity_tools/accounts", isDirectory: true)
        try FileManager.default.createDirectory(at: accounts, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try #"{"current_account_id":"account-1"}"#.write(
            to: root.appendingPathComponent(".antigravity_tools/accounts.json"),
            atomically: true,
            encoding: .utf8
        )
        try """
        {
          "email": "fixture@example.com",
          "quota": {
            "subscription_tier": "g1-pro-tier",
            "quota_groups": [
              {
                "displayName": "Gemini Models",
                "buckets": [
                  { "bucketId": "gemini-5h", "window": "5h", "remainingFraction": 0.75 },
                  { "bucketId": "gemini-weekly", "window": "weekly", "remainingFraction": 0.5 }
                ]
              }
            ]
          }
        }
        """.write(to: accounts.appendingPathComponent("account-1.json"), atomically: true, encoding: .utf8)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AntigravityURLProtocol.self]
        let cached = try XCTUnwrap(AntigravityDirectApiClient(
            homeURL: root,
            session: URLSession(configuration: configuration),
            allowKeychain: false
        ).readLocalCachedAccountData())

        XCTAssertEqual(cached.account.email, "fixture@example.com")
        XCTAssertEqual(cached.account.planType, "PRO")
        XCTAssertEqual(cached.windows.map(\.usedPercent), [25, 50])
    }

    func testUnauthorizedQuotaResponseSurfacesCredentialExpiry() async throws {
        AntigravityURLProtocol.statusCode = 403
        AntigravityURLProtocol.blocks = false
        defer { AntigravityURLProtocol.statusCode = 200 }
        let (root, client) = try makeNetworkFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        do {
            _ = try await client.fetch()
            XCTFail("鉴权失败不应被转换成普通端点错误")
        } catch {
            guard case AntigravityDirectApiError.credentialExpired = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testFetchPropagatesCancellation() async throws {
        AntigravityURLProtocol.statusCode = 200
        AntigravityURLProtocol.blocks = true
        defer { AntigravityURLProtocol.blocks = false }
        let (root, client) = try makeNetworkFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let task = Task { try await client.fetch() }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("取消后不应返回账号数据")
        } catch {
            XCTAssertTrue(error is CancellationError || (error as NSError).code == NSURLErrorCancelled)
        }
    }

    func testLoadFailureDoesNotInventFreeTier() async throws {
        AntigravityURLProtocol.statusCode = 200
        AntigravityURLProtocol.blocks = false
        AntigravityURLProtocol.loadStatusCode = 500
        AntigravityURLProtocol.quotaBody = #"{"groups":[{"displayName":"Gemini Models","buckets":[{"window":"5h","remainingFraction":0.8}]}]}"#
        defer {
            AntigravityURLProtocol.loadStatusCode = nil
            AntigravityURLProtocol.quotaBody = "{}"
        }
        let (root, client) = try makeNetworkFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try await client.fetch()

        XCTAssertNil(result.account.planType)
        XCTAssertEqual(result.windows.count, 1)
    }

    private func makeNetworkFixture() throws -> (URL, AntigravityDirectApiClient) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("antigravity-network-\(UUID().uuidString)", isDirectory: true)
        let credentials = root.appendingPathComponent(".gemini/antigravity-cli", isDirectory: true)
        try FileManager.default.createDirectory(at: credentials, withIntermediateDirectories: true)
        try #"{"access_token":"old-token","refresh_token":"refresh-token","email":"fixture@example.com"}"#.write(
            to: credentials.appendingPathComponent("antigravity-oauth-token"),
            atomically: true,
            encoding: .utf8
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AntigravityURLProtocol.self]
        let client = AntigravityDirectApiClient(
            homeURL: root,
            session: URLSession(configuration: configuration),
            allowKeychain: false
        )
        return (root, client)
    }
}

private final class AntigravityURLProtocol: URLProtocol {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var blocks = false
    nonisolated(unsafe) static var loadStatusCode: Int?
    nonisolated(unsafe) static var quotaBody = "{}"

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard !Self.blocks, let url = request.url else { return }
        let isLoad = url.path.contains("loadCodeAssist")
        let statusCode = isLoad ? (Self.loadStatusCode ?? Self.statusCode) : Self.statusCode
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let body = url.path.contains("retrieveUserQuotaSummary") ? Self.quotaBody : "{}"
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
