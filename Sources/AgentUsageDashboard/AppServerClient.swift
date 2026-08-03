import Foundation

struct CodexAccountData {
    var account: AccountIdentity?
    var windows: [RateLimitWindow]
    var usage: AccountTokenUsage?
}

enum AppServerError: LocalizedError {
    case executableNotFound
    case processFailed(String)
    case invalidResponse
    case rpcError(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound: return "找不到 codex 命令"
        case .processFailed(let message): return message
        case .invalidResponse: return "Codex App Server 返回了无法识别的数据"
        case .rpcError(let message): return message
        }
    }
}

struct CodexAppServerClient {
    var executableURL: URL? = CodexAppServerClient.findCodexExecutable()

    func fetch() async throws -> CodexAccountData {
        guard let executableURL else { throw AppServerError.executableNotFound }

        let input = Pipe()
        let output = Pipe()
        let errorOutput = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorOutput

        try process.run()

        let requests: [[String: Any]] = [
            [
                "method": "initialize",
                "id": 0,
                "params": [
                    "clientInfo": [
                        "name": "agent_usage_dashboard",
                        "title": "Agent Usage Dashboard",
                        "version": "0.1.0"
                    ]
                ]
            ],
            ["method": "initialized", "params": [:]],
            ["method": "account/read", "id": 1, "params": ["refreshToken": false]],
            ["method": "account/rateLimits/read", "id": 2],
            ["method": "account/usage/read", "id": 3]
        ]

        for request in requests {
            let data = try JSONSerialization.data(withJSONObject: request)
            input.fileHandleForWriting.write(data)
            input.fileHandleForWriting.write(Data([0x0A]))
        }
        input.fileHandleForWriting.closeFile()

        let outputTask = Task.detached {
            output.fileHandleForReading.readDataToEndOfFile()
        }
        let timeoutTask = Task.detached {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if process.isRunning { process.terminate() }
        }

        let outputData = await outputTask.value
        timeoutTask.cancel()
        if process.isRunning { process.terminate() }
        process.waitUntilExit()

        guard let text = String(data: outputData, encoding: .utf8) else {
            throw AppServerError.invalidResponse
        }
        return try parse(text)
    }

    private func parse(_ text: String) throws -> CodexAccountData {
        var account: AccountIdentity?
        var windows: [RateLimitWindow] = []
        var usage: AccountTokenUsage?
        var errors: [String] = []

        for line in text.split(whereSeparator: { $0.isNewline }) {
            guard let object = JSONSupport.jsonObject(from: String(line)) else { continue }
            if let error = object["error"] as? [String: Any] {
                errors.append(JSONSupport.string(error["message"]) ?? "未知错误")
                continue
            }
            guard let id = JSONSupport.int(object["id"]),
                  let result = object["result"] as? [String: Any] else { continue }

            switch id {
            case 1:
                if let accountObject = result["account"] as? [String: Any] {
                    account = AccountIdentity(
                        planType: JSONSupport.string(accountObject["planType"]),
                        email: JSONSupport.string(accountObject["email"])
                    )
                }
            case 2:
                windows = parseRateLimits(result)
            case 3:
                usage = parseUsage(result)
            default:
                break
            }
        }

        if !errors.isEmpty && account == nil && windows.isEmpty && usage == nil {
            throw AppServerError.rpcError(errors.joined(separator: "; "))
        }

        return CodexAccountData(account: account, windows: windows, usage: usage)
    }

    private func parseRateLimits(_ result: [String: Any]) -> [RateLimitWindow] {
        let buckets = (result["rateLimitsByLimitId"] as? [String: Any])
            ?? ["codex": result["rateLimits"] as Any]

        return buckets.compactMap { key, value in
            guard let object = value as? [String: Any] else { return nil }
            let primary = object["primary"] as? [String: Any]
            guard let primary else { return nil }
            return RateLimitWindow(
                id: key,
                usedPercent: JSONSupport.double(primary["usedPercent"] ?? primary["used_percent"]) ?? 0,
                windowMinutes: JSONSupport.int(primary["windowDurationMins"] ?? primary["window_minutes"]),
                resetsAt: JSONSupport.dateFromUnixSeconds(primary["resetsAt"] ?? primary["resets_at"])
            )
        }
        .sorted { $0.id < $1.id }
    }

    private func parseUsage(_ result: [String: Any]) -> AccountTokenUsage {
        let summary = result["summary"] as? [String: Any]
        let isoFormatter = ISO8601DateFormatter()
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let buckets = (result["dailyUsageBuckets"] as? [[String: Any]])?.compactMap { bucket -> DailyTokenBucket? in
            guard let dateString = JSONSupport.string(bucket["startDate"]),
                  let date = isoFormatter.date(from: dateString) ?? dayFormatter.date(from: dateString) else { return nil }
            return DailyTokenBucket(startDate: date, tokens: JSONSupport.int(bucket["tokens"]) ?? 0)
        }
        return AccountTokenUsage(
            lifetimeTokens: JSONSupport.int(summary?["lifetimeTokens"]),
            peakDailyTokens: JSONSupport.int(summary?["peakDailyTokens"]),
            dailyBuckets: buckets
        )
    }

    private static func findCodexExecutable() -> URL? {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        let manager = FileManager.default
        let home = manager.homeDirectoryForCurrentUser
        let roots = paths.map { URL(fileURLWithPath: $0) } + [
            home.appendingPathComponent(".local/bin"),
            home.appendingPathComponent(".volta/bin"),
            home.appendingPathComponent(".asdf/shims"),
            home.appendingPathComponent(".npm-global/bin"),
            URL(fileURLWithPath: "/opt/homebrew/bin"),
            URL(fileURLWithPath: "/usr/local/bin")
        ]

        for root in roots {
            let url = root.appendingPathComponent("codex")
            if manager.isExecutableFile(atPath: url.path) { return url }
        }

        let nvmRoot = home.appendingPathComponent(".nvm/versions/node", isDirectory: true)
        let nodeVersions = (try? manager.contentsOfDirectory(
            at: nvmRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for version in nodeVersions.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
            let url = version.appendingPathComponent("bin/codex")
            if manager.isExecutableFile(atPath: url.path) { return url }
        }
        return nil
    }
}
