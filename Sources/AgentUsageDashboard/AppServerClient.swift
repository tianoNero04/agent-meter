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

        let text = try await Task.detached(priority: .utility) {
            try Self.runProcess(executableURL: executableURL)
        }.value
        return try Self.parse(text)
    }

    private static func runProcess(executableURL: URL) throws -> String {

        let input = Pipe()
        let output = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        try process.run()

        let timeoutTimer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timeoutTimer.schedule(deadline: .now() + .seconds(8))
        timeoutTimer.setEventHandler {
            if process.isRunning { process.terminate() }
        }
        timeoutTimer.resume()
        defer {
            timeoutTimer.cancel()
            input.fileHandleForWriting.closeFile()
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
        }

        let initialize: [String: Any] = [
            "method": "initialize",
            "id": 0,
            "params": [
                "clientInfo": [
                    "name": "agent_usage_dashboard",
                    "title": "Agent Usage Dashboard",
                    "version": "0.1.0"
                ]
            ]
        ]
        let initialized: [String: Any] = ["method": "initialized", "params": [:]]
        let accountRead: [String: Any] = [
            "method": "account/read",
            "id": 1,
            "params": ["refreshToken": false]
        ]
        let rateLimitsRead: [String: Any] = ["method": "account/rateLimits/read", "id": 2]
        let usageRead: [String: Any] = ["method": "account/usage/read", "id": 3]

        var lines: [String] = []
        try send(initialize, to: input.fileHandleForWriting)
        try readUntilResponse(id: 0, from: output.fileHandleForReading, lines: &lines)

        try send(initialized, to: input.fileHandleForWriting)
        for (id, request) in [(1, accountRead), (2, rateLimitsRead), (3, usageRead)] {
            try send(request, to: input.fileHandleForWriting)
            try readUntilResponse(id: id, from: output.fileHandleForReading, lines: &lines)
        }

        return lines.joined(separator: "\n")
    }

    private static func send(_ request: [String: Any], to handle: FileHandle) throws {
        let data = try JSONSerialization.data(withJSONObject: request)
        handle.write(data)
        handle.write(Data([0x0A]))
    }

    private static func readUntilResponse(
        id: Int,
        from handle: FileHandle,
        lines: inout [String]
    ) throws {
        while let line = try readLine(from: handle) {
            lines.append(line)
            guard let object = JSONSupport.jsonObject(from: line) else { continue }
            if JSONSupport.int(object["id"]) == id { return }
        }
        throw AppServerError.invalidResponse
    }

    private static func readLine(from handle: FileHandle) throws -> String? {
        var data = Data()
        while true {
            guard let chunk = try handle.read(upToCount: 1), !chunk.isEmpty else {
                return data.isEmpty ? nil : String(data: data, encoding: .utf8)
            }
            data.append(chunk)
            if chunk.last == 0x0A {
                return String(data: data, encoding: .utf8)
            }
        }
    }

    private static func parse(_ text: String) throws -> CodexAccountData {
        var account: AccountIdentity?
        var windows: [RateLimitWindow] = []
        var usage: AccountTokenUsage?
        var errors: [String] = []
        var accountResponseSeen = false

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
                accountResponseSeen = true
                if let accountObject = result["account"] as? [String: Any] {
                    account = AccountIdentity(
                        planType: JSONSupport.string(accountObject["planType"]),
                        email: JSONSupport.string(accountObject["email"])
                    )
                }
            case 2:
                accountResponseSeen = true
                windows = Self.parseRateLimits(result)
            case 3:
                accountResponseSeen = true
                usage = Self.parseUsage(result)
            default:
                break
            }
        }

        if !errors.isEmpty && account == nil && windows.isEmpty && usage == nil {
            throw AppServerError.rpcError(errors.joined(separator: "; "))
        }
        guard accountResponseSeen else { throw AppServerError.invalidResponse }

        return CodexAccountData(account: account, windows: windows, usage: usage)
    }

    static func parseRateLimits(_ result: [String: Any]) -> [RateLimitWindow] {
        let buckets: [(String, [String: Any])] = {
            if let byLimitID = result["rateLimitsByLimitId"] as? [String: Any], !byLimitID.isEmpty {
                return byLimitID.compactMap { key, value in
                    guard let bucket = value as? [String: Any] else { return nil }
                    return (key, bucket)
                }
            }

            guard let direct = result["rateLimits"] as? [String: Any] else { return [] }
            if direct["primary"] is [String: Any] || direct["secondary"] is [String: Any] {
                return [("codex", direct)]
            }
            return direct.compactMap { key, value in
                guard let bucket = value as? [String: Any] else { return nil }
                return (key, bucket)
            }
        }()

        var windows: [RateLimitWindow] = []
        for (key, bucket) in buckets {
            var parsed: [(String, RateLimitWindow)] = []
            for role in ["primary", "secondary"] {
                guard let window = bucket[role] as? [String: Any],
                      let used = JSONSupport.double(window["usedPercent"] ?? window["used_percent"]) else {
                    continue
                }
                parsed.append((role, RateLimitWindow(
                    id: key,
                    usedPercent: used,
                    windowMinutes: JSONSupport.int(window["windowDurationMins"] ?? window["window_minutes"]),
                    resetsAt: JSONSupport.dateFromUnixSeconds(window["resetsAt"] ?? window["resets_at"])
                )))
            }

            let hasMultipleWindows = parsed.count > 1
            for (role, var window) in parsed {
                if hasMultipleWindows { window.id = "\(key).\(role)" }
                windows.append(window)
            }
        }
        return windows.sorted { $0.id < $1.id }
    }

    private static func parseUsage(_ result: [String: Any]) -> AccountTokenUsage {
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
