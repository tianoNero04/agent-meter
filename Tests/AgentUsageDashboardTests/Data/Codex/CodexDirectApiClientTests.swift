import XCTest
@testable import AgentUsageDashboardKit

final class CodexDirectApiClientTests: XCTestCase {
    /// 验证 wham/usage 接口返回报文的解析逻辑（5小时窗口、7天窗口、订阅类型与邮箱）
    func testParseResponseExtractsPlanAndWindows() throws {
        let jsonString = """
        {
          "user_id": "user-123",
          "account_id": "acc-456",
          "email": "developer@example.com",
          "plan_type": "plus",
          "rate_limit": {
            "allowed": true,
            "limit_reached": false,
            "primary_window": {
              "used_percent": 23,
              "limit_window_seconds": 18000,
              "reset_after_seconds": 4624,
              "reset_at": 1788432270
            },
            "secondary_window": {
              "used_percent": 89,
              "limit_window_seconds": 604800,
              "reset_after_seconds": 320410,
              "reset_at": 1788748056
            }
          }
        }
        """
        let data = jsonString.data(using: .utf8)!
        let result = try CodexDirectApiClient.parseResponse(data: data)

        XCTAssertEqual(result.account?.planType, "plus")
        XCTAssertEqual(result.account?.email, "developer@example.com")
        XCTAssertEqual(result.windows.count, 2)

        let primary = result.windows.first { $0.id == "codex.primary" }
        XCTAssertNotNil(primary)
        XCTAssertEqual(primary?.usedPercent, 23)
        XCTAssertEqual(primary?.windowMinutes, 300)
        XCTAssertEqual(primary?.resetsAt, Date(timeIntervalSince1970: 1788432270))

        let secondary = result.windows.first { $0.id == "codex.secondary" }
        XCTAssertNotNil(secondary)
        XCTAssertEqual(secondary?.usedPercent, 89)
        XCTAssertEqual(secondary?.windowMinutes, 10080)
        XCTAssertEqual(secondary?.resetsAt, Date(timeIntervalSince1970: 1788748056))
    }

    /// 验证凭据 JSON 的提取逻辑（access_token 与 account_id）
    func testParseCredentialsJsonExtractsToken() throws {
        let jsonString = """
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "access_token": "mock-access-token-123",
            "account_id": "org-mock-456"
          }
        }
        """
        let data = jsonString.data(using: .utf8)!
        let (token, accountId) = try CodexDirectApiClient.parseCredentialsJson(data)

        XCTAssertEqual(token, "mock-access-token-123")
        XCTAssertEqual(accountId, "org-mock-456")
    }

    /// 验证非 chatgpt 模式时报错
    func testParseCredentialsJsonRejectsNonChatGPTMode() {
        let jsonString = """
        {
          "auth_mode": "api_key",
          "tokens": {
            "access_token": "abc"
          }
        }
        """
        let data = jsonString.data(using: .utf8)!
        XCTAssertThrowsError(try CodexDirectApiClient.parseCredentialsJson(data))
    }

    /// 验证从本地目录 ~/.codex/auth.json 读取凭据
    func testReadCredentialsFromDiskFallback() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-creds-\(UUID().uuidString)", isDirectory: true)
        let codexDir = tempDir.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let authFile = codexDir.appendingPathComponent("auth.json")
        let content = """
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "access_token": "disk-token-789"
          }
        }
        """
        try content.write(to: authFile, atomically: true, encoding: .utf8)

        let client = CodexDirectApiClient(homeURL: tempDir)
        let (token, accountId) = try client.readCredentials()
        XCTAssertEqual(token, "disk-token-789")
        XCTAssertNil(accountId)
    }
}
