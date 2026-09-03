import Foundation

/// Kimi Code 官方账号额度与身份数据结构
struct KimiAccountData: Equatable {
    var account: AccountIdentity
    var windows: [RateLimitWindow]
}

/// Kimi Code 官方直连客户端错误类型
enum KimiDirectApiError: LocalizedError, Equatable {
    case credentialNotFound
    case credentialParseError(String)
    case credentialExpired(Int)
    case httpError(Int, String)
    case invalidResponseData
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .credentialNotFound:
            return "未检测到 Kimi Code 登录凭据，请在终端使用 kimi 登录"
        case .credentialParseError(let detail):
            return "Kimi 凭据解析失败：\(detail)"
        case .credentialExpired(let code):
            return "Kimi 登录凭据已失效 (HTTP \(code))，请在终端重新登录 kimi"
        case .httpError(let code, let msg):
            return "Kimi 官方额度接口返回错误 (HTTP \(code))：\(msg)"
        case .invalidResponseData:
            return "Kimi 官方额度接口返回了无法识别的数据"
        case .networkError(let msg):
            return "网络连接异常：\(msg)"
        }
    }
}

/// Kimi Code 官方额度轻量直连客户端：
/// 1. 从 ~/.kimi-code/credentials/kimi-code.json 读取 access_token 与 refresh_token；
/// 2. 具备自动静默续期能力：当 access_token 过期或遭遇 401 时，向 https://auth.kimi.com/api/oauth/token 换取新令牌；
/// 3. 直接向 https://api.kimi.com/coding/v1/usages 发送轻量级 HTTPS 请求，百毫秒级返回 5小时 与 周额度窗口；
/// 4. 彻底免除子进程或 PTY 交互，全程纯原生异步网络请求。
struct KimiDirectApiClient {
    var homeURL: URL = FileManager.default.homeDirectoryForCurrentUser
    var session: URLSession = .shared

    /// 官方 OAuth 客户端 ID
    static let defaultClientId = "17e5f671-d194-4dfb-9706-5516cb48c098"

    /// 执行获取 Kimi 官方额度数据
    func fetch() async throws -> KimiAccountData {
        // 1. 读取本地凭据
        var creds = try readCredentials()

        // 2. 若凭据已过期或即将过期（提前 60 秒），尝试静默刷新
        let nowUnix = Int(Date().timeIntervalSince1970)
        if creds.expiresAt <= nowUnix + 60, !creds.refreshToken.isEmpty {
            if let refreshed = try? await refreshAccessToken(refreshToken: creds.refreshToken) {
                creds = refreshed
                saveCredentialsQuietly(creds)
            }
        }

        // 3. 发送额度查询请求
        do {
            return try await executeFetchUsages(accessToken: creds.accessToken)
        } catch let err as KimiDirectApiError {
            // 若遇 401 鉴权失效，尝试用 refresh_token 重试一次
            if case .credentialExpired = err, !creds.refreshToken.isEmpty {
                let refreshed = try await refreshAccessToken(refreshToken: creds.refreshToken)
                saveCredentialsQuietly(refreshed)
                return try await executeFetchUsages(accessToken: refreshed.accessToken)
            }
            throw err
        }
    }

    /// 执行查询 usages 接口
    private func executeFetchUsages(accessToken: String) async throws -> KimiAccountData {
        var request = URLRequest(url: URL(string: "https://api.kimi.com/coding/v1/usages")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("kimi-code", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                throw error
            }
            throw KimiDirectApiError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KimiDirectApiError.invalidResponseData
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw KimiDirectApiError.credentialExpired(httpResponse.statusCode)
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw KimiDirectApiError.httpError(httpResponse.statusCode, errorBody)
        }

        // 顺带查询 /me 获取用户昵称（若失败不阻塞额度展示）
        let nickname = await fetchNicknameQuietly(accessToken: accessToken)

        return try Self.parseUsagesResponse(data: data, nickname: nickname)
    }

    /// 轻量获取用户昵称
    private func fetchNicknameQuietly(accessToken: String) async -> String? {
        var request = URLRequest(url: URL(string: "https://api.kimi.com/coding/v1/me")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 4.0
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("kimi-code", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["nickname"] as? String
    }

    /// 刷新 OAuth 访问令牌
    func refreshAccessToken(refreshToken: String) async throws -> KimiCredentials {
        var request = URLRequest(url: URL(string: "https://auth.kimi.com/api/oauth/token")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("kimi-code", forHTTPHeaderField: "User-Agent")

        let bodyParams = [
            "client_id": Self.defaultClientId,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw KimiDirectApiError.networkError("Token 续期失败：\(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw KimiDirectApiError.invalidResponseData
        }

        guard http.statusCode == 200 else {
            throw KimiDirectApiError.credentialExpired(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccess = json["access_token"] as? String, !newAccess.isEmpty else {
            throw KimiDirectApiError.invalidResponseData
        }

        let newRefresh = (json["refresh_token"] as? String) ?? refreshToken
        let expiresIn = (json["expires_in"] as? NSNumber)?.intValue ?? 3600
        let expiresAt = Int(Date().timeIntervalSince1970) + expiresIn
        let scope = json["scope"] as? String ?? ""

        return KimiCredentials(
            accessToken: newAccess,
            refreshToken: newRefresh,
            expiresAt: expiresAt,
            scope: scope
        )
    }

    /// 从本地凭据文件 ~/.kimi-code/credentials/kimi-code.json 读取凭据
    func readCredentials() throws -> KimiCredentials {
        let path = homeURL.appendingPathComponent(".kimi-code/credentials/kimi-code.json")
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw KimiDirectApiError.credentialNotFound
        }

        do {
            let data = try Data(contentsOf: path)
            return try Self.parseCredentialsJson(data)
        } catch let err as KimiDirectApiError {
            throw err
        } catch {
            throw KimiDirectApiError.credentialParseError(error.localizedDescription)
        }
    }

    /// 静默写回更新后的凭据文件
    private func saveCredentialsQuietly(_ creds: KimiCredentials) {
        let path = homeURL.appendingPathComponent(".kimi-code/credentials/kimi-code.json")
        let dict: [String: Any] = [
            "access_token": creds.accessToken,
            "refresh_token": creds.refreshToken,
            "expires_at": creds.expiresAt,
            "scope": creds.scope,
            "token_type": "Bearer"
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) {
            try? data.write(to: path, options: .atomic)
        }
    }

    /// 解析凭据文件内容
    static func parseCredentialsJson(_ data: Data) throws -> KimiCredentials {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KimiDirectApiError.credentialParseError("凭据不是合法的 JSON")
        }

        guard let accessToken = json["access_token"] as? String, !accessToken.isEmpty else {
            throw KimiDirectApiError.credentialParseError("缺少 access_token")
        }

        let refreshToken = json["refresh_token"] as? String ?? ""
        let expiresAt = (json["expires_at"] as? NSNumber)?.intValue ?? 0
        let scope = json["scope"] as? String ?? ""

        return KimiCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            scope: scope
        )
    }

    /// 解析 usages 接口返回报文（包含 5 小时短期窗口与 7 天周窗口）
    static func parseUsagesResponse(data: Data, nickname: String?) throws -> KimiAccountData {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KimiDirectApiError.invalidResponseData
        }

        // 1. 计划与身份解析
        let membershipLevel = JSONSupport.string(JSONSupport.value(json, path: ["user", "membership", "level"]))
        let planType: String = {
            if let level = membershipLevel {
                return level.replacingOccurrences(of: "LEVEL_", with: "")
            }
            return "KIMI CODE"
        }()

        let account = AccountIdentity(
            planType: planType,
            email: nickname ?? JSONSupport.string(JSONSupport.value(json, path: ["user", "userId"]))
        )

        var windows: [RateLimitWindow] = []

        // 2. 解析 5 小时窗口（limits 列表中 duration: 300 节点）
        if let limits = json["limits"] as? [[String: Any]] {
            for item in limits {
                let duration = JSONSupport.int(JSONSupport.value(item, path: ["window", "duration"]))
                if duration == 300 || windows.isEmpty {
                    if let detail = item["detail"] as? [String: Any] {
                        let limit = JSONSupport.double(detail["limit"]) ?? 100.0
                        let remaining = JSONSupport.double(detail["remaining"]) ?? limit
                        let usedPercent = limit > 0 ? max(0, min(100, ((limit - remaining) / limit) * 100.0)) : 0.0
                        let resetsAt = JSONSupport.date(detail["resetTime"])

                        windows.append(RateLimitWindow(
                            id: "kimi.primary",
                            usedPercent: usedPercent,
                            windowMinutes: 300,
                            resetsAt: resetsAt
                        ))
                        break
                    }
                }
            }
        }

        // 3. 解析周额度窗口（usage 节点，重置周期通常为 7 天）
        if let usage = json["usage"] as? [String: Any] {
            let limit = JSONSupport.double(usage["limit"]) ?? 100.0
            let used = JSONSupport.double(usage["used"]) ?? 0.0
            let usedPercent = limit > 0 ? max(0, min(100, (used / limit) * 100.0)) : 0.0
            let resetsAt = JSONSupport.date(usage["resetTime"])

            windows.append(RateLimitWindow(
                id: "kimi.secondary",
                usedPercent: usedPercent,
                windowMinutes: 10080, // 7 天周额度对应 10080 分钟
                resetsAt: resetsAt
            ))
        }

        return KimiAccountData(account: account, windows: windows)
    }
}

/// Kimi OAuth 凭据模型
struct KimiCredentials: Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Int
    var scope: String
}
