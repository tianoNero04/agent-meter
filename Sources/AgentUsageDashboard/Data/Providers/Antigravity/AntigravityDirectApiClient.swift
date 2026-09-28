import Foundation

/// Antigravity 官方直连 API 客户端错误类型
enum AntigravityDirectApiError: LocalizedError, Equatable {
    case credentialNotFound
    case credentialParseError(String)
    case credentialExpired(Int)
    case httpError(Int, String)
    case invalidResponseData
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .credentialNotFound:
            return "未检测到 Antigravity 登录凭据，请在 Antigravity 中登录账号"
        case .credentialParseError(let detail):
            return "Antigravity 凭据解析失败：\(detail)"
        case .credentialExpired(let code):
            return "Antigravity 凭据已失效 (HTTP \(code))，请在 Antigravity 中重新登录"
        case .httpError(let code, let msg):
            return "官方额度接口返回错误 (HTTP \(code))：\(msg)"
        case .invalidResponseData:
            return "官方额度接口返回了无法识别的数据"
        case .networkError(let msg):
            return "网络连接异常：\(msg)"
        }
    }
}

/// 官方直连获取到的 Antigravity 账号与额度窗口数据
struct AntigravityAccountData: Equatable {
    var account: AccountIdentity
    var windows: [RateLimitWindow]
}

/// Antigravity 内部凭据结构
struct AntigravityCredentials: Equatable {
    var accessToken: String
    var refreshToken: String?
    var email: String?
    var projectId: String?
}

/// Antigravity 官方额度直连客户端：
/// 1. 优先读取 macOS Keychain 中的 gemini/antigravity 凭据，回退读取 ~/.antigravity_tools 或 ~/.gemini；
/// 2. 支持 access_token 过期时自动使用 refresh_token 刷新；
/// 3. 轻量请求 Google Cloud Code 内部 loadCodeAssist 与 retrieveUserQuotaSummary 接口获取实时额度。
struct AntigravityDirectApiClient {
    var homeURL: URL = FileManager.default.homeDirectoryForCurrentUser
    var session: URLSession = .shared
    /// 是否允许访问系统 Keychain（测试使用临时目录时为 false，避免访问真实钥匙串）
    var allowKeychain: Bool = true

    /// Google OAuth 刷新端点
    private static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    /// Google Cloud Code loadCodeAssist 内部接口端点列表（优先正式生产端点，兼顾 Sandbox 容灾）
    private static let loadCodeAssistEndpoints: [URL] = [
        URL(string: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist")!,
        URL(string: "https://daily-cloudcode-pa.sandbox.googleapis.com/v1internal:loadCodeAssist")!
    ]

    /// Google Cloud Code retrieveUserQuotaSummary 内部接口端点列表（优先正式生产端点，兼顾 Sandbox 容灾）
    private static let quotaSummaryEndpoints: [URL] = [
        URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary")!,
        URL(string: "https://daily-cloudcode-pa.sandbox.googleapis.com/v1internal:retrieveUserQuotaSummary")!
    ]

    /// 获取 Antigravity 额度与身份数据（多源候选凭据容错）
    func fetch() async throws -> AntigravityAccountData {
        let candidates = readAllCandidateCredentials()
        guard !candidates.isEmpty else {
            throw AntigravityDirectApiError.credentialNotFound
        }

        var lastError: Error?
        for creds in candidates {
            do {
                return try await executeFetch(creds: creds)
            } catch AntigravityDirectApiError.credentialExpired {
                if let refreshToken = creds.refreshToken, !refreshToken.isEmpty,
                   let newAccessToken = try? await refreshAccessToken(refreshToken: refreshToken) {
                    var refreshed = creds
                    refreshed.accessToken = newAccessToken
                    if let result = try? await executeFetch(creds: refreshed) {
                        return result
                    }
                }
                lastError = AntigravityDirectApiError.credentialExpired(401)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? AntigravityDirectApiError.credentialNotFound
    }

    /// 执行网络请求流程：先获取 project_id 与 tier，再获取配额摘要（均具备端点自动容灾降级）
    private func executeFetch(creds: AntigravityCredentials) async throws -> AntigravityAccountData {
        // 1. 调用 loadCodeAssist（按顺序尝试三级端点）
        var loadData: Data?
        for endpoint in Self.loadCodeAssistEndpoints {
            let req = makePostRequest(url: endpoint, accessToken: creds.accessToken, body: [
                "metadata": ["ideType": "ANTIGRAVITY"]
            ])
            if let (data, resp) = try? await sendRequest(req), resp.statusCode == 200 {
                loadData = data
                break
            }
        }

        let resolvedProjectId: String?
        let rawTier: String?
        if let validLoadData = loadData {
            let parsed = Self.parseLoadCodeAssist(data: validLoadData)
            resolvedProjectId = parsed.projectId
            rawTier = parsed.tierName
        } else {
            resolvedProjectId = nil
            rawTier = nil
        }

        let projectId = creds.projectId ?? resolvedProjectId
        let tier = Self.normalizeTier(rawTier)

        // 2. 调用 retrieveUserQuotaSummary（按顺序尝试三级端点）
        var summaryBody: [String: Any] = [:]
        if let pid = projectId, !pid.isEmpty {
            summaryBody["project"] = pid
        }
        var summaryData: Data?
        for endpoint in Self.quotaSummaryEndpoints {
            let req = makePostRequest(url: endpoint, accessToken: creds.accessToken, body: summaryBody)
            if let (data, resp) = try? await sendRequest(req), resp.statusCode == 200 {
                summaryData = data
                break
            }
        }

        guard let validSummaryData = summaryData else {
            throw AntigravityDirectApiError.httpError(403, "所有 retrieveUserQuotaSummary 端点均不可用")
        }

        let windows = Self.parseQuotaSummary(data: validSummaryData)
        guard !windows.isEmpty else {
            throw AntigravityDirectApiError.invalidResponseData
        }

        return AntigravityAccountData(
            account: AccountIdentity(planType: tier, email: creds.email),
            windows: windows
        )
    }

    /// 发送 HTTPS POST 请求并检查状态码
    private func sendRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                throw error
            }
            throw AntigravityDirectApiError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AntigravityDirectApiError.invalidResponseData
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw AntigravityDirectApiError.credentialExpired(httpResponse.statusCode)
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw AntigravityDirectApiError.httpError(httpResponse.statusCode, errorBody)
        }

        return (data, httpResponse)
    }

    /// 构造标准的 JSON POST 请求（使用 Antigravity 官方客户端 User-Agent，设置 5 秒短超时防止挂起卡顿）
    private func makePostRequest(url: URL, accessToken: String, body: [String: Any]) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 5.0
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("vscode/1.96.2 (Antigravity/4.3.0)", forHTTPHeaderField: "User-Agent")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    /// 使用 refresh_token 刷新 access_token
    func refreshAccessToken(refreshToken: String) async throws -> String {
        let clientId = ProcessInfo.processInfo.environment["ANTIGRAVITY_CLIENT_ID"] ?? ""
        let clientSecret = ProcessInfo.processInfo.environment["ANTIGRAVITY_CLIENT_SECRET"] ?? ""
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            // 本地未显式配置客户端凭据时，交由本地 Antigravity-Manager 自动刷新，平滑回退
            throw AntigravityDirectApiError.credentialExpired(401)
        }
        var req = URLRequest(url: Self.tokenEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let postParams = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        let bodyString = postParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        req.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await session.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AntigravityDirectApiError.credentialExpired(401)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String, !newAccessToken.isEmpty else {
            throw AntigravityDirectApiError.invalidResponseData
        }

        return newAccessToken
    }

    /// 读取所有可用的候选凭据（用于按序容灾尝试：Keychain -> ~/.antigravity_tools -> ~/.gemini）
    func readAllCandidateCredentials() -> [AntigravityCredentials] {
        var candidates: [AntigravityCredentials] = []

        // 1. 尝试从 macOS Keychain 读取
        if allowKeychain, let keychainData = readKeychainGenericPassword(service: "gemini", account: "antigravity") {
            if let creds = try? Self.parseKeyringPayload(keychainData) {
                candidates.append(creds)
            }
        }

        // 2. 尝试从 ~/.antigravity_tools/accounts.json 和 accounts/<id>.json 读取
        let toolsAccountPath = homeURL.appendingPathComponent(".antigravity_tools/accounts.json")
        if FileManager.default.fileExists(atPath: toolsAccountPath.path),
           let data = try? Data(contentsOf: toolsAccountPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let currentId = json["current_account_id"] as? String {
            let detailPath = homeURL.appendingPathComponent(".antigravity_tools/accounts/\(currentId).json")
            if FileManager.default.fileExists(atPath: detailPath.path),
               let detailData = try? Data(contentsOf: detailPath),
               let detailJson = try? JSONSerialization.jsonObject(with: detailData) as? [String: Any] {
                if let creds = Self.parseToolsAccountJson(detailJson) {
                    candidates.append(creds)
                }
            }
        }

        // 3. 尝试从 ~/.gemini/antigravity-cli/antigravity-oauth-token 或 jetski-standalone-oauth-token 读取
        let geminiCliToken = homeURL.appendingPathComponent(".gemini/antigravity-cli/antigravity-oauth-token")
        if FileManager.default.fileExists(atPath: geminiCliToken.path),
           let data = try? Data(contentsOf: geminiCliToken),
           let creds = try? Self.parseKeyringPayload(data) {
            candidates.append(creds)
        }

        let jetskiToken = homeURL.appendingPathComponent(".gemini/jetski-standalone-oauth-token")
        if FileManager.default.fileExists(atPath: jetskiToken.path),
           let data = try? Data(contentsOf: jetskiToken),
           let creds = try? Self.parseKeyringPayload(data) {
            candidates.append(creds)
        }

        return candidates
    }

    /// 读取首选凭据（向后兼容单次读取调用）
    func readCredentials() throws -> AntigravityCredentials {
        guard let first = readAllCandidateCredentials().first else {
            throw AntigravityDirectApiError.credentialNotFound
        }
        return first
    }

    /// 读取本地缓存的账户身份与配额数据（若存在 ~/.antigravity_tools 账户数据则免网解析）
    func readLocalCachedAccountData() -> AntigravityAccountData? {
        let toolsAccountPath = homeURL.appendingPathComponent(".antigravity_tools/accounts.json")
        guard FileManager.default.fileExists(atPath: toolsAccountPath.path),
              let data = try? Data(contentsOf: toolsAccountPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let currentId = json["current_account_id"] as? String else {
            return nil
        }
        let detailPath = homeURL.appendingPathComponent(".antigravity_tools/accounts/\(currentId).json")
        guard FileManager.default.fileExists(atPath: detailPath.path),
              let detailData = try? Data(contentsOf: detailPath),
              let detailJson = try? JSONSerialization.jsonObject(with: detailData) as? [String: Any] else {
            return nil
        }

        let email = detailJson["email"] as? String
        let quota = detailJson["quota"] as? [String: Any]
        let rawTier = quota?["subscription_tier"] as? String
        let tier = Self.normalizeTier(rawTier)

        var windows: [RateLimitWindow] = []
        if let quota = quota, let groups = quota["quota_groups"] as? [[String: Any]],
           let groupsData = try? JSONSerialization.data(withJSONObject: ["groups": groups]) {
            windows = Self.parseQuotaSummary(data: groupsData)
        }

        guard email != nil || !windows.isEmpty else { return nil }

        return AntigravityAccountData(
            account: AccountIdentity(planType: tier, email: email),
            windows: windows
        )
    }

    /// 从 Keychain 读取通用密码
    private func readKeychainGenericPassword(service: String, account: String) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-a", account, "-w"]

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

    /// 解析 Keychain/CLI 返回的 payload 数据（兼容 go-keyring-base64: 前缀）
    static func parseKeyringPayload(_ data: Data) throws -> AntigravityCredentials {
        let rawString = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var jsonString = rawString

        if rawString.hasPrefix("go-keyring-base64:") {
            let base64Part = String(rawString.dropFirst("go-keyring-base64:".count))
            if let decodedData = Data(base64Encoded: base64Part),
               let decoded = String(data: decodedData, encoding: .utf8) {
                jsonString = decoded
            }
        }

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AntigravityDirectApiError.credentialParseError("凭据不是有效的 JSON")
        }

        // 解析 token 节点
        let tokenObj = json["token"] as? [String: Any] ?? json
        guard let accessToken = tokenObj["access_token"] as? String, !accessToken.isEmpty else {
            throw AntigravityDirectApiError.credentialParseError("凭据缺少有效的 access_token")
        }

        let refreshToken = tokenObj["refresh_token"] as? String
        var email = json["email"] as? String ?? tokenObj["email"] as? String

        // 若无直接 email，尝试从 id_token 解码 JWT payload
        if email == nil, let idToken = json["id_token"] as? String ?? tokenObj["id_token"] as? String {
            email = parseEmailFromJWT(idToken)
        }

        return AntigravityCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            email: email,
            projectId: nil
        )
    }

    /// 解析 ~/.antigravity_tools/accounts/<id>.json 文件
    static func parseToolsAccountJson(_ json: [String: Any]) -> AntigravityCredentials? {
        let email = json["email"] as? String
        guard let token = json["token"] as? [String: Any],
              let accessToken = token["access_token"] as? String, !accessToken.isEmpty else {
            return nil
        }
        let refreshToken = token["refresh_token"] as? String
        let projectId = token["project_id"] as? String

        return AntigravityCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            email: email,
            projectId: projectId
        )
    }

    /// 从 JWT 字符串解码 payload 中的 email 字段
    static func parseEmailFromJWT(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = json["email"] as? String else {
            return nil
        }
        return email
    }

    /// 解析 loadCodeAssist 响应，优先机器识别字段 paidTier.id（如 g1-pro-tier）
    static func parseLoadCodeAssist(data: Data) -> (projectId: String?, tierName: String?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil)
        }
        let project = json["cloudaicompanionProject"] as? String

        // 优先权威机器字段 paidTier.id（如 g1-pro-tier / g1-ultra-tier）
        let paidTierObj = json["paidTier"] as? [String: Any]
        let paidTierId = paidTierObj?["id"] as? String
        let paidTierName = paidTierObj?["name"] as? String

        let currentTierObj = json["currentTier"] as? [String: Any]
        let currentTierId = currentTierObj?["id"] as? String
        let currentTierName = currentTierObj?["name"] as? String

        let rawTier = paidTierId ?? paidTierName ?? currentTierId ?? currentTierName
        return (project, rawTier)
    }

    /// 标准化订阅计划级别
    static func normalizeTier(_ raw: String?) -> String {
        guard let tier = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !tier.isEmpty else {
            return "FREE"
        }
        if tier.contains("ultra") || tier.contains("helium") {
            return "ULTRA"
        }
        if tier.contains("pro") || tier.contains("premium") || tier.contains("advanced") {
            return "PRO"
        }
        return "FREE"
    }

    /// 解析 retrieveUserQuotaSummary 响应，提取 Gemini 的 5 小时与周额度窗口（与 Codex/Kimi 一致）
    static func parseQuotaSummary(data: Data) -> [RateLimitWindow] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groups = json["groups"] as? [[String: Any]] else {
            return []
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackIsoFormatter = ISO8601DateFormatter()
        fallbackIsoFormatter.formatOptions = [.withInternetDateTime]

        func parseDate(_ str: String?) -> Date? {
            guard let str = str else { return nil }
            return isoFormatter.date(from: str) ?? fallbackIsoFormatter.date(from: str)
        }

        // 仅提取 Gemini Models 组，与 Codex/Kimi 统一展示 5 小时与周额度
        guard let geminiGroup = groups.first(where: {
            let name = ($0["displayName"] as? String ?? $0["display_name"] as? String ?? "").lowercased()
            return name.contains("gemini")
        }) ?? groups.first else {
            return []
        }

        let buckets = geminiGroup["buckets"] as? [[String: Any]] ?? []

        var window5h: RateLimitWindow?
        var windowWeekly: RateLimitWindow?

        for bucket in buckets {
            let w = (bucket["window"] as? String ?? "").lowercased()
            let id = (bucket["bucketId"] as? String ?? bucket["bucket_id"] as? String ?? "").lowercased()
            let remaining = (bucket["remainingFraction"] as? NSNumber ?? bucket["remaining_fraction"] as? NSNumber)?.doubleValue ?? 1.0
            let usedPercent = max(0.0, min(100.0, (1.0 - remaining) * 100.0))
            let resetsAt = parseDate(bucket["resetTime"] as? String ?? bucket["reset_time"] as? String)

            if w == "5h" || id.contains("5h") {
                window5h = RateLimitWindow(
                    id: "antigravity.5h",
                    usedPercent: usedPercent,
                    windowMinutes: 300,
                    resetsAt: resetsAt,
                    name: nil
                )
            } else if w == "weekly" || w == "7d" || id.contains("weekly") {
                windowWeekly = RateLimitWindow(
                    id: "antigravity.weekly",
                    usedPercent: usedPercent,
                    windowMinutes: 10080,
                    resetsAt: resetsAt,
                    name: nil
                )
            }
        }

        var result: [RateLimitWindow] = []
        if let w5 = window5h {
            result.append(w5)
        }
        if let ww = windowWeekly {
            result.append(ww)
        }
        return result
    }
}
