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

        XCTAssertEqual(windows.count, 2)

        let w5h = try XCTUnwrap(windows.first { $0.id == "antigravity.5h" })
        XCTAssertEqual(w5h.label, "5 小时")
        XCTAssertEqual(w5h.windowMinutes, 300)
        XCTAssertEqual(w5h.usedPercent, 20.0, accuracy: 0.1)

        let wWeekly = try XCTUnwrap(windows.first { $0.id == "antigravity.weekly" })
        XCTAssertEqual(wWeekly.label, "本周")
        XCTAssertEqual(wWeekly.windowMinutes, 10080)
        XCTAssertEqual(wWeekly.usedPercent, 5.0, accuracy: 0.1)
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

    func testReadLocalCachedAccountData() {
        let client = AntigravityDirectApiClient()
        let cached = client.readLocalCachedAccountData()
        let toolsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".antigravity_tools/accounts.json").path
        if FileManager.default.fileExists(atPath: toolsPath) {
            XCTAssertNotNil(cached)
            XCTAssertNotNil(cached?.account.email)
            XCTAssertFalse(cached?.windows.isEmpty ?? true)
        }
    }

    func testFetchRealAccountData() async throws {
        let client = AntigravityDirectApiClient()
        let toolsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".antigravity_tools/accounts.json").path
        if FileManager.default.fileExists(atPath: toolsPath) {
            if let data = try? await client.fetch() {
                XCTAssertNotNil(data.account.email)
                XCTAssertEqual(data.windows.count, 2)
                XCTAssertEqual(data.windows[0].windowMinutes, 300)
                XCTAssertEqual(data.windows[1].windowMinutes, 10080)
            }
        }
    }
}
