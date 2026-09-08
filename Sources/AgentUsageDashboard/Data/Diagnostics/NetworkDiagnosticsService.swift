import Foundation

/// 网络健康与延迟探测结果
public struct DiagnosticResult: Sendable, Hashable {
    /// 探测目标名称（如 "Codex 官方直连通道", "Kimi Code API"）
    public let targetName: String
    /// 是否连通成功
    public let isSuccess: Bool
    /// 端到端往返延迟（毫秒）
    public let latencyMs: Int
    /// HTTP 响应码（若有）
    public let statusCode: Int?
    /// 诊断说明或错误详情
    public let detail: String

    public init(
        targetName: String,
        isSuccess: Bool,
        latencyMs: Int,
        statusCode: Int? = nil,
        detail: String
    ) {
        self.targetName = targetName
        self.isSuccess = isSuccess
        self.latencyMs = latencyMs
        self.statusCode = statusCode
        self.detail = detail
    }
}

/// 提供纯按需、单次触发的网络连通性与延迟探测服务，平时绝无任何后台网络活动
public final class NetworkDiagnosticsService: Sendable {
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4.0
        configuration.timeoutIntervalForResource = 5.0
        self.session = URLSession(configuration: configuration)
    }

    /// 单次探测指定目标端点延迟
    public func ping(targetName: String, url: URL) async -> DiagnosticResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let (_, response) = try await session.data(for: request)
            let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            let httpResponse = response as? HTTPURLResponse
            let code = httpResponse?.statusCode ?? 200

            return DiagnosticResult(
                targetName: targetName,
                isSuccess: code < 500,
                latencyMs: max(1, elapsedMs),
                statusCode: code,
                detail: "HTTP \(code) · 握手连通正常"
            )
        } catch {
            let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            let nsError = error as NSError
            let isTimeout = nsError.code == NSURLErrorTimedOut
            let desc = isTimeout ? "连接超时（4.0s）" : "连接失败：\(error.localizedDescription)"

            return DiagnosticResult(
                targetName: targetName,
                isSuccess: false,
                latencyMs: elapsedMs,
                statusCode: nil,
                detail: desc
            )
        }
    }

    /// 已知主流 Agent 官方与云端服务探测端点映射
    public static let knownEndpoints: [String: (name: String, url: URL)] = [
        "codex": ("Codex 官方通道", URL(string: "https://chatgpt.com/api/auth/session")!),
        "kimi": ("Kimi Code 通道", URL(string: "https://api.moonshot.cn")!),
        "antigravity": ("Google Antigravity 通道", URL(string: "https://generativelanguage.googleapis.com")!),
        "claude": ("Claude Code (Anthropic) 通道", URL(string: "https://api.anthropic.com")!),
        "cursor": ("Cursor AI 服务通道", URL(string: "https://api2.cursor.sh")!),
        "vscode": ("VS Code Copilot 通道", URL(string: "https://api.githubcopilot.com")!),
        "grok": ("xAI Grok 服务通道", URL(string: "https://api.x.ai/v1")!),
        "opencode": ("OpenCode 服务通道", URL(string: "https://opencode.ai")!),
        "openclaw": ("OpenClaw 服务通道", URL(string: "https://openclaw.ai")!),
        "hermes": ("Nous Hermes 服务通道", URL(string: "https://nousresearch.com")!),
        "pi": ("Pi 智能助手通道", URL(string: "https://inflection.ai")!),
        "ollama": ("Ollama 本地引擎", URL(string: "http://localhost:11434")!)
    ]

    /// 并行探测指定目标端点列表并按原序返回结果
    public func runDiagnostics(targets: [(id: String, name: String, url: URL)]) async -> [DiagnosticResult] {
        await withTaskGroup(of: DiagnosticResult.self) { group in
            for target in targets {
                group.addTask {
                    await self.ping(targetName: target.name, url: target.url)
                }
            }

            var results: [DiagnosticResult] = []
            for await res in group {
                results.append(res)
            }

            // 按传入 targets 的相对顺序排序
            return results.sorted { a, b in
                let idxA = targets.firstIndex { $0.name == a.targetName } ?? 99
                let idxB = targets.firstIndex { $0.name == b.targetName } ?? 99
                return idxA < idxB
            }
        }
    }

    /// 一键并行探测默认的主流服务商通道节点
    public func runFullDiagnostics() async -> [DiagnosticResult] {
        let targets = [
            ("codex", "Codex 官方通道", URL(string: "https://chatgpt.com/api/auth/session")!),
            ("kimi", "Kimi Code 通道", URL(string: "https://api.moonshot.cn")!),
            ("antigravity", "Google Antigravity 通道", URL(string: "https://generativelanguage.googleapis.com")!),
            ("claude", "Claude Code (Anthropic) 通道", URL(string: "https://api.anthropic.com")!),
            ("cursor", "Cursor AI 服务通道", URL(string: "https://api2.cursor.sh")!)
        ]
        return await runDiagnostics(targets: targets)
    }
}
