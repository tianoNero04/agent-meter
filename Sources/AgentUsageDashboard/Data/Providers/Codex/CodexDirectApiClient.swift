import Foundation

/// 仿照 cc-switch 实现的 Codex 官方直连 API 客户端错误类型
enum CodexDirectApiError: LocalizedError, Equatable {
    case credentialNotFound
    case credentialParseError(String)
    case credentialExpired(Int) // 401 或 403
    case httpError(Int, String)
    case invalidResponseData
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .credentialNotFound:
            return "未检测到 Codex 登录凭据，请在终端使用 codex 登录"
        case .credentialParseError(let detail):
            return "Codex 凭据解析失败：\(detail)"
        case .credentialExpired(let code):
            return "Codex 凭据已过期 (HTTP \(code))，请在终端重新登录 codex"
        case .httpError(let code, let msg):
            return "官方额度接口返回错误 (HTTP \(code))：\(msg)"
        case .invalidResponseData:
            return "官方额度接口返回了无法识别的数据"
        case .networkError(let msg):
            return "网络连接异常：\(msg)"
        }
    }
}

/// 仿照 cc-switch 实现的 Codex 官方额度直连客户端：
/// 1. 优先从 macOS Keychain 读取凭据，未果则读取 ~/.codex/auth.json；
/// 2. 直接向 https://chatgpt.com/backend-api/wham/usage 发送轻量级 HTTPS 请求；
/// 3. 无需启动 node/codex 等子进程，响应在毫秒级完成。
struct CodexDirectApiClient {
    var homeURL: URL = FileManager.default.homeDirectoryForCurrentUser
    var session: URLSession = .shared
    /// 是否允许访问系统 Keychain（在测试使用临时目录时为 false，避免读取真实用户钥匙串）
    var allowKeychain: Bool = true

    /// 执行直接获取官方额度数据
    func fetch() async throws -> CodexAccountData {
        // 1. 读取并解析 OAuth 凭据
        let creds = try readCredentials()

        // 2. 构造直接请求
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountId = creds.accountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        // 3. 执行异步 HTTPS 网络请求
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                throw error // 响应取消事件，支持面板关闭时及时终止
            }
            throw CodexDirectApiError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexDirectApiError.invalidResponseData
        }

        // 4. 处理鉴权过期 (401 / 403)
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw CodexDirectApiError.credentialExpired(httpResponse.statusCode)
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw CodexDirectApiError.httpError(httpResponse.statusCode, errorBody)
        }

        // 5. 解析响应数据
        return try Self.parseResponse(data: data)
    }

    /// 读取 Codex 凭据（双通道：Keychain 优先，auth.json 兜底）
    func readCredentials() throws -> (accessToken: String, accountId: String?) {
        // 通道 1：尝试从 Keychain 读取（仅在生产环境用户主目录且允许 Keychain 时调用）
        if allowKeychain && homeURL.path == FileManager.default.homeDirectoryForCurrentUser.path {
            if let keychainJson = Self.readFromKeychain() {
                if let creds = try? Self.parseCredentialsJson(keychainJson) {
                    return creds
                }
            }
        }

        // 通道 2：从文件 ~/.codex/auth.json 读取
        let authPath = homeURL.appendingPathComponent(".codex/auth.json")
        guard FileManager.default.fileExists(atPath: authPath.path) else {
            throw CodexDirectApiError.credentialNotFound
        }

        do {
            let fileData = try Data(contentsOf: authPath)
            return try Self.parseCredentialsJson(fileData)
        } catch let err as CodexDirectApiError {
            throw err
        } catch {
            throw CodexDirectApiError.credentialParseError(error.localizedDescription)
        }
    }

    /// 从 macOS Keychain 提取 Codex Auth 密码串
    private static func readFromKeychain() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Codex Auth", "-w"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let trimmedString = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedString.isEmpty else { return nil }
            return trimmedString.data(using: .utf8)
        } catch {
            return nil
        }
    }

    /// 解析凭据 JSON 内容
    static func parseCredentialsJson(_ data: Data) throws -> (accessToken: String, accountId: String?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexDirectApiError.credentialParseError("凭据不是有效的 JSON")
        }

        // 验证 auth_mode 是否为 chatgpt OAuth 模式
        if let mode = json["auth_mode"] as? String, mode != "chatgpt" {
            throw CodexDirectApiError.credentialParseError("非 chatgpt 登录模式 (\(mode))")
        }

        // 提取 tokens 字段
        guard let tokens = json["tokens"] as? [String: Any] else {
            throw CodexDirectApiError.credentialParseError("凭据缺少 tokens 节点")
        }

        guard let accessToken = tokens["access_token"] as? String, !accessToken.isEmpty else {
            throw CodexDirectApiError.credentialParseError("凭据缺少有效的 access_token")
        }

        let accountId = tokens["account_id"] as? String
        return (accessToken, accountId)
    }

    /// 解析 wham/usage 接口返回的 JSON
    static func parseResponse(data: Data) throws -> CodexAccountData {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexDirectApiError.invalidResponseData
        }

        // 账号基本信息
        let planType = json["plan_type"] as? String
        let email = json["email"] as? String
        let account = AccountIdentity(planType: planType, email: email)

        var windows: [RateLimitWindow] = []

        // 解析 rate_limit 节点中的 primary_window 和 secondary_window
        if let rateLimit = json["rate_limit"] as? [String: Any] {
            if let primary = rateLimit["primary_window"] as? [String: Any] {
                if let window = parseWindow(primary, id: "codex.primary") {
                    windows.append(window)
                }
            }
            if let secondary = rateLimit["secondary_window"] as? [String: Any] {
                if let window = parseWindow(secondary, id: "codex.secondary") {
                    windows.append(window)
                }
            }
        }

        return CodexAccountData(account: account, windows: windows, usage: nil)
    }

    private static func parseWindow(_ dict: [String: Any], id: String) -> RateLimitWindow? {
        guard let used = (dict["used_percent"] as? NSNumber)?.doubleValue else { return nil }
        let seconds = (dict["limit_window_seconds"] as? NSNumber)?.intValue
        let windowMinutes = seconds.map { $0 / 60 }
        let resetsAt: Date? = {
            if let ts = (dict["reset_at"] as? NSNumber)?.doubleValue {
                return Date(timeIntervalSince1970: ts)
            }
            return nil
        }()

        return RateLimitWindow(
            id: id,
            usedPercent: used,
            windowMinutes: windowMinutes,
            resetsAt: resetsAt
        )
    }
}
