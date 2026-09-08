import Foundation

/// 本地 AI Agent 工具链与运行环境检测数据模型
public struct LocalToolEnvironment: Sendable, Identifiable, Hashable {
    /// 唯一标识（如 "codex", "kimi", "antigravity"）
    public let id: String
    /// 工具或应用展示名称
    public let name: String
    /// 开发商或生态归属（如 "OpenAI", "Moonshot AI", "Google DeepMind"）
    public let vendor: String
    /// 界面展示的 SF Symbol 图标名称
    public let iconName: String
    /// 是否已检测到在本机安装
    public let isInstalled: Bool
    /// 检测到的版本号字符串（若可用，格式如 "v1.2.3"）
    public let version: String?
    /// 可执行文件或应用程序包绝对路径（自动缩写为 ~/ 前缀）
    public let locationPath: String?
    /// 状态描述文本（如 "命令行已就绪", "应用与 CLI 已就绪", "未在系统路径中找到"）
    public let statusDescription: String

    public init(
        id: String,
        name: String,
        vendor: String,
        iconName: String,
        isInstalled: Bool,
        version: String?,
        locationPath: String?,
        statusDescription: String
    ) {
        self.id = id
        self.name = name
        self.vendor = vendor
        self.iconName = iconName
        self.isInstalled = isInstalled
        self.version = version
        self.locationPath = locationPath
        self.statusDescription = statusDescription
    }
}

/// 本地环境检测服务：负责并发扫描系统中的主流 AI Agent CLI 与桌面应用
public final class LocalEnvironmentInspector: Sendable {
    private var fileManager: FileManager { FileManager.default }

    public init() {}

    /// 执行全量工具链环境检测
    public func inspectAllTools() async -> [LocalToolEnvironment] {
        await withTaskGroup(of: LocalToolEnvironment.self) { group in
            // 1. Codex CLI
            group.addTask { await self.detectCodex() }
            // 2. Kimi Code
            group.addTask { await self.detectKimi() }
            // 3. Google Antigravity
            group.addTask { await self.detectAntigravity() }
            // 4. Claude Code
            group.addTask { await self.detectClaude() }
            // 5. Cursor IDE
            group.addTask { await self.detectCursor() }
            // 6. Visual Studio Code
            group.addTask { await self.detectVSCode() }
            // 7. Ollama
            group.addTask { await self.detectOllama() }

            var results: [LocalToolEnvironment] = []
            for await item in group {
                results.append(item)
            }

            // 按固定预设顺序返回，确保 UI 呈现稳定
            let order = ["codex", "kimi", "antigravity", "claude", "cursor", "vscode", "ollama"]
            return results.sorted { a, b in
                let indexA = order.firstIndex(of: a.id) ?? 99
                let indexB = order.firstIndex(of: b.id) ?? 99
                return indexA < indexB
            }
        }
    }

    // MARK: - 单项检测逻辑

    /// 检测 OpenAI Codex CLI
    private func detectCodex() async -> LocalToolEnvironment {
        let exe = findExecutable(named: "codex", extraSubpaths: [
            ".local/bin",
            ".volta/bin",
            ".asdf/shims",
            ".npm-global/bin"
        ])

        if let exe {
            let version = await runVersion(at: exe)
            return LocalToolEnvironment(
                id: "codex",
                name: "Codex CLI",
                vendor: "OpenAI",
                iconName: "terminal.fill",
                isInstalled: true,
                version: version.map { formatVersion($0) },
                locationPath: compactPath(exe.path),
                statusDescription: "官方命令行工具已安装就绪"
            )
        }

        return LocalToolEnvironment(
            id: "codex",
            name: "Codex CLI",
            vendor: "OpenAI",
            iconName: "terminal.fill",
            isInstalled: false,
            version: nil,
            locationPath: nil,
            statusDescription: "未在 PATH 或 ~/.local/bin 中检测到"
        )
    }

    /// 检测 Kimi Code (CLI 与桌面 App)
    private func detectKimi() async -> LocalToolEnvironment {
        let app = findApplication(named: "Kimi.app")
        let exe = findExecutable(named: "kimi", extraSubpaths: [
            ".kimi-code/bin",
            ".local/bin"
        ]) ?? findExecutable(named: "kimi-code", extraSubpaths: [
            ".kimi-code/bin",
            ".local/bin"
        ])

        let appVersion = app.flatMap { readAppVersion(url: $0) }
        let cliVersion = exe != nil ? await runVersion(at: exe!) : nil

        var versionParts: [String] = []
        if let cv = cliVersion { versionParts.append("CLI \(formatVersion(cv))") }
        if let av = appVersion { versionParts.append("App \(formatVersion(av))") }

        let isInstalled = (exe != nil || app != nil)
        let mainPath = exe?.path ?? app?.path

        let status: String
        if exe != nil && app != nil {
            status = "Kimi CLI 与桌面应用均已就绪"
        } else if exe != nil {
            status = "Kimi 命令行工具已就绪"
        } else if app != nil {
            status = "Kimi 桌面端应用已安装"
        } else {
            status = "未在系统路径或应用目录中找到"
        }

        return LocalToolEnvironment(
            id: "kimi",
            name: "Kimi Code",
            vendor: "Moonshot AI",
            iconName: "sparkles",
            isInstalled: isInstalled,
            version: versionParts.isEmpty ? nil : versionParts.joined(separator: " · "),
            locationPath: mainPath.map { compactPath($0) },
            statusDescription: status
        )
    }

    /// 检测 Google Antigravity (CLI 与 IDE/App)
    private func detectAntigravity() async -> LocalToolEnvironment {
        let ideApp = findApplication(named: "Antigravity IDE.app")
        let mainApp = findApplication(named: "Antigravity.app")
        let exe = findExecutable(named: "agy", extraSubpaths: [
            ".local/bin"
        ]) ?? findExecutable(named: "antigravity", extraSubpaths: [
            ".local/bin"
        ])

        let cliVersion = exe != nil ? await runVersion(at: exe!) : nil
        let ideVersion = ideApp.flatMap { readAppVersion(url: $0) }
        let mainAppVersion = mainApp.flatMap { readAppVersion(url: $0) }

        var versionParts: [String] = []
        if let cv = cliVersion { versionParts.append("CLI \(formatVersion(cv))") }
        if let iv = ideVersion { versionParts.append("IDE \(formatVersion(iv))") }
        else if let mv = mainAppVersion { versionParts.append("App \(formatVersion(mv))") }

        let isInstalled = (exe != nil || ideApp != nil || mainApp != nil)
        let primaryPath = exe?.path ?? ideApp?.path ?? mainApp?.path

        let status: String
        if exe != nil && (ideApp != nil || mainApp != nil) {
            status = "Antigravity CLI 与 IDE 均已就绪"
        } else if exe != nil {
            status = "Antigravity (agy) 命令行已就绪"
        } else if ideApp != nil || mainApp != nil {
            status = "Antigravity 桌面应用已安装"
        } else {
            status = "未检测到 Antigravity 工具链"
        }

        return LocalToolEnvironment(
            id: "antigravity",
            name: "Google Antigravity",
            vendor: "Google DeepMind",
            iconName: "atom",
            isInstalled: isInstalled,
            version: versionParts.isEmpty ? nil : versionParts.joined(separator: " · "),
            locationPath: primaryPath.map { compactPath($0) },
            statusDescription: status
        )
    }

    /// 检测 Anthropic Claude Code CLI
    private func detectClaude() async -> LocalToolEnvironment {
        let exe = findExecutable(named: "claude", extraSubpaths: [
            ".local/bin",
            ".npm-global/bin"
        ])

        if let exe {
            let version = await runVersion(at: exe)
            return LocalToolEnvironment(
                id: "claude",
                name: "Claude Code",
                vendor: "Anthropic",
                iconName: "apple.terminal.fill",
                isInstalled: true,
                version: version.map { formatVersion($0) },
                locationPath: compactPath(exe.path),
                statusDescription: "Claude Code 终端交互工具已就绪"
            )
        }

        return LocalToolEnvironment(
            id: "claude",
            name: "Claude Code",
            vendor: "Anthropic",
            iconName: "apple.terminal.fill",
            isInstalled: false,
            version: nil,
            locationPath: nil,
            statusDescription: "未在系统路径中检测到"
        )
    }

    /// 检测 Cursor IDE
    private func detectCursor() async -> LocalToolEnvironment {
        let app = findApplication(named: "Cursor.app")
        let exe = findExecutable(named: "cursor")

        let version = app.flatMap { readAppVersion(url: $0) }
        let isInstalled = (app != nil || exe != nil)
        let mainPath = app?.path ?? exe?.path

        return LocalToolEnvironment(
            id: "cursor",
            name: "Cursor IDE",
            vendor: "Anysphere",
            iconName: "cursorarrow.rays",
            isInstalled: isInstalled,
            version: version.map { formatVersion($0) },
            locationPath: mainPath.map { compactPath($0) },
            statusDescription: isInstalled ? "AI 原生代码编辑器已就绪" : "未在系统 /Applications 中找到"
        )
    }

    /// 检测 Visual Studio Code 与 GitHub Copilot Agent
    private func detectVSCode() async -> LocalToolEnvironment {
        let app = findApplication(named: "Visual Studio Code.app")
        let exe = findExecutable(named: "code")

        let appVersion = app.flatMap { readAppVersion(url: $0) }

        // 检索 GitHub Copilot 官方插件 (~/.vscode/extensions/github.copilot-*)
        let copilotExtension = findVSCodeExtension(namedPrefix: "github.copilot-")
            ?? findVSCodeExtension(namedPrefix: "github.copilot")
        let copilotVersion = copilotExtension.flatMap { readExtensionVersion(directoryURL: $0) }

        let isInstalled = (app != nil || exe != nil || copilotExtension != nil)
        let mainPath = copilotExtension?.path ?? app?.path ?? exe?.path

        var versionParts: [String] = []
        if let cv = copilotVersion { versionParts.append("Copilot \(formatVersion(cv))") }
        if let av = appVersion { versionParts.append("VS Code \(formatVersion(av))") }

        let status: String
        if copilotExtension != nil && (app != nil || exe != nil) {
            status = "VS Code 宿主与 Copilot 插件均已就绪"
        } else if copilotExtension != nil {
            status = "GitHub Copilot 插件已安装就绪"
        } else if app != nil || exe != nil {
            status = "VS Code 编辑器已就绪（支持在插件市场中激活 Copilot）"
        } else {
            status = "未在系统应用或扩展目录中检测到"
        }

        return LocalToolEnvironment(
            id: "vscode",
            name: "VS Code Copilot",
            vendor: "GitHub / Microsoft",
            iconName: "chevron.left.forwardslash.chevron.right",
            isInstalled: isInstalled,
            version: versionParts.isEmpty ? nil : versionParts.joined(separator: " · "),
            locationPath: mainPath.map { compactPath($0) },
            statusDescription: status
        )
    }

    /// 检测 Ollama 本地模型服务
    private func detectOllama() async -> LocalToolEnvironment {
        let app = findApplication(named: "Ollama.app")
        let exe = findExecutable(named: "ollama")

        let appVer = app.flatMap { readAppVersion(url: $0) }
        let cliVer = exe != nil ? await runVersion(at: exe!) : nil
        let ver = cliVer ?? appVer

        let isInstalled = (app != nil || exe != nil)
        let mainPath = exe?.path ?? app?.path

        return LocalToolEnvironment(
            id: "ollama",
            name: "Ollama",
            vendor: "Local LLM",
            iconName: "cpu",
            isInstalled: isInstalled,
            version: ver.map { formatVersion($0) },
            locationPath: mainPath.map { compactPath($0) },
            statusDescription: isInstalled ? "本地大模型推理引擎已就绪" : "未检测到本地部署实例"
        )
    }

    // MARK: - 辅助发现工具方法

    /// 在标准 PATH 及扩展候选路径中定位可执行二进制
    public func findExecutable(named name: String, extraSubpaths: [String] = []) -> URL? {
        let envPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        let home = fileManager.homeDirectoryForCurrentUser
        var candidateRoots = envPaths.map { URL(fileURLWithPath: $0) } + [
            URL(fileURLWithPath: "/opt/homebrew/bin"),
            URL(fileURLWithPath: "/usr/local/bin"),
            URL(fileURLWithPath: "/usr/bin"),
            URL(fileURLWithPath: "/bin")
        ]

        for sub in extraSubpaths {
            candidateRoots.append(home.appendingPathComponent(sub, isDirectory: true))
        }

        // 检索候选目录
        for root in candidateRoots {
            let fileURL = root.appendingPathComponent(name)
            if fileManager.isExecutableFile(atPath: fileURL.path) {
                return fileURL
            }
        }

        // 深入扫描 NVM 路径 (~/.nvm/versions/node/*/bin)
        let nvmNodeRoot = home.appendingPathComponent(".nvm/versions/node", isDirectory: true)
        if let nodeVersions = try? fileManager.contentsOfDirectory(
            at: nvmNodeRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for version in nodeVersions.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
                let fileURL = version.appendingPathComponent("bin/\(name)")
                if fileManager.isExecutableFile(atPath: fileURL.path) {
                    return fileURL
                }
            }
        }

        return nil
    }

    /// 在 Applications 目录查找应用包
    public func findApplication(named name: String) -> URL? {
        let home = fileManager.homeDirectoryForCurrentUser
        let candidateDirs = [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]

        for dir in candidateDirs {
            let appURL = dir.appendingPathComponent(name)
            if fileManager.fileExists(atPath: appURL.path) {
                return appURL
            }
        }
        return nil
    }

    /// 从 .app 包中读取 CFBundleShortVersionString
    public func readAppVersion(url: URL) -> String? {
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let version = dict["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return version
    }

    /// 在 ~/.vscode/extensions 或 ~/.vscode-insiders/extensions 查找指定前缀的插件目录
    public func findVSCodeExtension(namedPrefix prefix: String) -> URL? {
        let home = fileManager.homeDirectoryForCurrentUser
        let candidateRoots = [
            home.appendingPathComponent(".vscode/extensions", isDirectory: true),
            home.appendingPathComponent(".vscode-insiders/extensions", isDirectory: true)
        ]

        for root in candidateRoots {
            guard let items = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            // 倒序排列以优先选用最新版本（如 github.copilot-1.250.0 优先于旧版本）
            let matches = items
                .filter { $0.lastPathComponent.hasPrefix(prefix) }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }

            if let first = matches.first {
                return first
            }
        }
        return nil
    }

    /// 从 VS Code 扩展插件包的 package.json 中解析版本号
    public func readExtensionVersion(directoryURL: URL) -> String? {
        let packageJSONURL = directoryURL.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: packageJSONURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String else {
            return nil
        }
        return version
    }

    /// 异步调用可执行文件的 --version 参数，带 1.5 秒硬超时安全保护
    public func runVersion(at executableURL: URL, timeout: TimeInterval = 1.5) async -> String? {
        await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            process.executableURL = executableURL
            process.arguments = ["--version"]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                return nil
            }

            let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                if process.isRunning { process.terminate() }
            }
            timer.resume()

            process.waitUntilExit()
            timer.cancel()

            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { return nil }
            return raw
        }.value
    }

    /// 提取并格式化版本号（如将 "codex-cli 0.142.5" 转换为 "v0.142.5"）
    public func formatVersion(_ raw: String) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 匹配首个 x.y.z 或 x.y 数字模式
        if let regex = try? NSRegularExpression(pattern: #"(\d+\.\d+(?:\.\d+)?)"#),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let range = Range(match.range(at: 1), in: cleaned) {
            let ver = String(cleaned[range])
            return "v\(ver)"
        }
        return cleaned.hasPrefix("v") ? cleaned : "v\(cleaned)"
    }

    /// 缩短用户路径展示（将 /Users/xxx 替换为 ~/）
    public func compactPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return path.replacingOccurrences(of: home, with: "~")
        }
        return path
    }
}
