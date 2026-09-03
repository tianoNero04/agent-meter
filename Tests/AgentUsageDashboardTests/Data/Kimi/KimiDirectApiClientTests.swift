import XCTest
@testable import AgentUsageDashboardKit

final class KimiDirectApiClientTests: XCTestCase {
    /// 验证 Kimi usages 接口返回报文的解析逻辑（5 小时短期窗口、7 天周额度窗口与会员等级）
    func testParseUsagesResponseExtractsPlanAndWindows() throws {
        let jsonString = """
        {
          "user": {
            "userId": "ct3bu66akqcgn3f9t63g",
            "region": "REGION_CN",
            "membership": {
              "level": "LEVEL_INTERMEDIATE"
            }
          },
          "usage": {
            "limit": "100",
            "used": "99",
            "remaining": "1",
            "resetTime": "2026-09-07T01:51:45.747767Z"
          },
          "limits": [
            {
              "window": {
                "duration": 300,
                "timeUnit": "TIME_UNIT_MINUTE"
              },
              "detail": {
                "limit": "100",
                "remaining": "100",
                "resetTime": "2026-09-03T09:51:45.747767Z"
              }
            }
          ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let result = try KimiDirectApiClient.parseUsagesResponse(data: data, nickname: "登月者7632")

        XCTAssertEqual(result.account.planType, "INTERMEDIATE")
        XCTAssertEqual(result.account.email, "登月者7632")
        XCTAssertEqual(result.windows.count, 2)

        // 5 小时窗口
        let primary = result.windows.first { $0.id == "kimi.primary" }
        XCTAssertNotNil(primary)
        XCTAssertEqual(primary?.windowMinutes, 300)
        XCTAssertEqual(primary?.usedPercent, 0.0) // 100 - 100 = 0%
        XCTAssertNotNil(primary?.resetsAt)

        // 7 天周窗口
        let secondary = result.windows.first { $0.id == "kimi.secondary" }
        XCTAssertNotNil(secondary)
        XCTAssertEqual(secondary?.windowMinutes, 10080)
        XCTAssertEqual(secondary?.usedPercent, 99.0) // 99 / 100 = 99%
        XCTAssertNotNil(secondary?.resetsAt)
    }

    /// 验证从本地 JSON 提取 access_token 与 refresh_token
    func testParseCredentialsJsonExtractsTokens() throws {
        let jsonString = """
        {
          "access_token": "mock-kimi-access-token",
          "refresh_token": "mock-kimi-refresh-token",
          "expires_at": 1788396886,
          "token_type": "Bearer"
        }
        """
        let data = jsonString.data(using: .utf8)!
        let creds = try KimiDirectApiClient.parseCredentialsJson(data)

        XCTAssertEqual(creds.accessToken, "mock-kimi-access-token")
        XCTAssertEqual(creds.refreshToken, "mock-kimi-refresh-token")
        XCTAssertEqual(creds.expiresAt, 1788396886)
    }

    /// 验证凭据文件缺失时抛出明确错误
    func testMissingCredentialsThrowsNotFound() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kimi-empty-\(UUID().uuidString)", isDirectory: true)
        let client = KimiDirectApiClient(homeURL: tempDir)

        XCTAssertThrowsError(try client.readCredentials()) { error in
            guard let directErr = error as? KimiDirectApiError else {
                return XCTFail("Unexpected error type: \(error)")
            }
            XCTAssertEqual(directErr, .credentialNotFound)
        }
    }
}
