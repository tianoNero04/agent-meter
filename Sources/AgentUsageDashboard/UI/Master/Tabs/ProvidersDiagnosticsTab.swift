import SwiftUI

/// 服务商管理与网络健康测速雷达面板
struct ProvidersDiagnosticsTab: View {
    @ObservedObject var model: DashboardModel
    @Binding var latencyBadge: String?

    @State private var isTesting = false
    @State private var diagnosticResults: [DiagnosticResult] = []
    @State private var isDetectingEnv = false
    @State private var toolEnvironments: [LocalToolEnvironment] = []
    /// 已启用通道诊断的检测 Agent 集合（默认包含所有已探测到的工具）
    @State private var enabledAgentIds: Set<String> = ["antigravity", "claude", "cursor", "vscode", "ollama"]

    private let diagnosticsService = NetworkDiagnosticsService()
    private let environmentInspector = LocalEnvironmentInspector()

    /// 本地已检测到安装的额外 Agent（排除已内置在核心模型中的 codex 和 kimi）
    private var detectedExtraAgents: [LocalToolEnvironment] {
        toolEnvironments.filter { tool in
            tool.isInstalled && tool.id != "codex" && tool.id != "kimi"
        }
    }

    init(model: DashboardModel, latencyBadge: Binding<String?>) {
        self.model = model
        self._latencyBadge = latencyBadge
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // 顶栏刊头标示
                HStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.codex)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("服务商与网络健康诊断")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("PROVIDERS // RADAR.DIAGNOSTICS")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    Spacer()

                    // 一键网络测速按钮（平时零网络，纯按需触发）
                    Button {
                        runDiagnostics()
                    } label: {
                        HStack(spacing: 6) {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.65)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "bolt.horizontal.fill")
                                    .font(.system(size: 11, weight: .semibold))
                            }

                            Text(isTesting ? "测速中..." : "一键测试连接")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(AppTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(AppTheme.hairlineBright, lineWidth: 0.75)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting)
                }

                // 服务商与 Agent 通道状态列表
                VStack(spacing: 12) {
                    providerCard(for: .codex, title: "Codex (OpenAI)", credentialHint: "读取 Keychain 或 ~/.codex/auth.json")
                    providerCard(for: .kimiCode, title: "Kimi Code (Moonshot)", credentialHint: "读取 ~/.kimi-code/credentials/kimi-code.json")

                    // 动态加入检测到的本地 Agent（如 Google Antigravity, Claude Code, Cursor 等）
                    ForEach(detectedExtraAgents) { agent in
                        detectedAgentCard(for: agent)
                    }
                }

                // 网络诊断雷达结果卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("通道连通性与网络延迟 (Ping & TTFT)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Text("单次按需探测 · 零后台常驻")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    if diagnosticResults.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 24, weight: .ultraLight))
                                    .foregroundStyle(AppTheme.tertiaryText)
                                Text("点击右上角「一键测试连接」探测直连端点网络延迟")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            .padding(.vertical, 24)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 8) {
                            ForEach(diagnosticResults, id: \.targetName) { result in
                                HStack {
                                    Circle()
                                        .fill(result.isSuccess ? AppTheme.success : AppTheme.warning)
                                        .frame(width: 6, height: 6)

                                    Text(result.targetName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.primaryText)

                                    Spacer()

                                    Text("\(result.latencyMs) ms")
                                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(result.latencyMs < 200 ? AppTheme.success : AppTheme.warning)

                                    Text(result.detail)
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundStyle(AppTheme.tertiaryText)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(AppTheme.background.opacity(0.6))
                                )
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                        .fill(AppTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                                .stroke(AppTheme.hairline, lineWidth: 0.75)
                        )
                )

                // 本地 Agent 与开发环境检查卡片
                localEnvironmentSection

                Spacer(minLength: 20)
            }
            .padding(.top, 44)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            if toolEnvironments.isEmpty {
                runEnvironmentInspection()
            }
        }
    }

    /// 服务商状态配置卡片
    private func providerCard(for provider: Provider, title: String, credentialHint: String) -> some View {
        let isEnabled = model.navigation.isEnabled(provider)

        return HStack(spacing: 12) {
            Image(systemName: provider.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.codex)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(credentialHint)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in model.setProviderEnabled(provider, enabled: !isEnabled) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                        .stroke(AppTheme.hairline, lineWidth: 0.75)
                )
        )
    }

    /// 已检测到的本地 Agent 服务商卡片
    private func detectedAgentCard(for agent: LocalToolEnvironment) -> some View {
        let isEnabled = enabledAgentIds.contains(agent.id)

        return HStack(spacing: 12) {
            Image(systemName: agent.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.codex)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(agent.name) (\(agent.vendor))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    if let ver = agent.version {
                        Text(ver)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.success)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppTheme.success.opacity(0.12))
                            )
                    } else {
                        Text("已就绪")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(AppTheme.success)
                    }
                }

                Text(agent.locationPath ?? agent.statusDescription)
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { enable in
                    if enable {
                        enabledAgentIds.insert(agent.id)
                    } else {
                        enabledAgentIds.remove(agent.id)
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                        .stroke(AppTheme.hairline, lineWidth: 0.75)
                )
        )
    }

    /// 触发单次按需测速（覆盖当前已启用的服务商与已检测到的 Agent 通道）
    private func runDiagnostics() {
        guard !isTesting else { return }
        isTesting = true

        Task { @MainActor in
            var targets: [(id: String, name: String, url: URL)] = []

            // 1. 核心 Provider (Codex / Kimi)
            if model.navigation.isEnabled(.codex),
               let ep = NetworkDiagnosticsService.knownEndpoints["codex"] {
                targets.append((id: "codex", name: ep.name, url: ep.url))
            }
            if model.navigation.isEnabled(.kimiCode),
               let ep = NetworkDiagnosticsService.knownEndpoints["kimi"] {
                targets.append((id: "kimi", name: ep.name, url: ep.url))
            }

            // 2. 本地已检测到且已启用的额外 Agent
            for agent in detectedExtraAgents where enabledAgentIds.contains(agent.id) {
                if let ep = NetworkDiagnosticsService.knownEndpoints[agent.id] {
                    targets.append((id: agent.id, name: ep.name, url: ep.url))
                }
            }

            // 兜底保护：若全未选中，则探测默认核心端点
            if targets.isEmpty {
                if let ep = NetworkDiagnosticsService.knownEndpoints["codex"] {
                    targets.append((id: "codex", name: ep.name, url: ep.url))
                }
                if let ep = NetworkDiagnosticsService.knownEndpoints["kimi"] {
                    targets.append((id: "kimi", name: ep.name, url: ep.url))
                }
            }

            let results = await diagnosticsService.runDiagnostics(targets: targets)
            self.diagnosticResults = results
            self.isTesting = false

            // 取有效结果的平均延迟作为侧边栏徽标更新
            let successful = results.filter(\.isSuccess)
            if !successful.isEmpty {
                let avg = successful.map(\.latencyMs).reduce(0, +) / successful.count
                self.latencyBadge = "\(avg)ms"
            }
        }
    }

    // MARK: - 本地 Agent 运行环境检测卡片

    /// 本地工具链与 Agent 环境检测卡片组件
    private var localEnvironmentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.codex)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("本地 Agent 运行环境检测")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("ENVIRONMENT // LOCAL.AGENT.TOOLCHAINS")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }

                Spacer()

                // 一键环境检测按钮
                Button {
                    runEnvironmentInspection()
                } label: {
                    HStack(spacing: 5) {
                        if isDetectingEnv {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        Text(isDetectingEnv ? "探测中..." : "一键环境检测")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(AppTheme.background.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(AppTheme.hairlineBright, lineWidth: 0.75)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDetectingEnv)
            }

            if toolEnvironments.isEmpty && !isDetectingEnv {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 22, weight: .ultraLight))
                            .foregroundStyle(AppTheme.tertiaryText)
                        Text("点击右上角「一键环境检测」扫描本机 Codex、Kimi、Antigravity 等工具链")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(toolEnvironments) { tool in
                        HStack(spacing: 12) {
                            Image(systemName: tool.iconName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(tool.isInstalled ? AppTheme.codex : AppTheme.tertiaryText)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(tool.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.primaryText)

                                    Text(tool.vendor)
                                        .font(.system(size: 9.5, weight: .regular))
                                        .foregroundStyle(AppTheme.tertiaryText)

                                    if let ver = tool.version {
                                        Text(ver)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(AppTheme.success)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(AppTheme.success.opacity(0.12))
                                            )
                                    }
                                }

                                if let path = tool.locationPath {
                                    Text(path)
                                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .lineLimit(1)
                                } else {
                                    Text(tool.statusDescription)
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundStyle(AppTheme.tertiaryText)
                                }
                            }

                            Spacer()

                            // 安装就绪微标
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(tool.isInstalled ? AppTheme.success : AppTheme.tertiaryText.opacity(0.5))
                                    .frame(width: 6, height: 6)

                                Text(tool.isInstalled ? "已就绪" : "未检测到")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(tool.isInstalled ? AppTheme.success : AppTheme.tertiaryText)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.background.opacity(tool.isInstalled ? 0.6 : 0.25))
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                        .stroke(AppTheme.hairline, lineWidth: 0.75)
                )
        )
    }

    /// 触发单次本地 Agent 与工具链环境检测
    private func runEnvironmentInspection() {
        guard !isDetectingEnv else { return }
        isDetectingEnv = true

        Task { @MainActor in
            let tools = await environmentInspector.inspectAllTools()
            self.toolEnvironments = tools
            // 自动将新检测到的已安装 agent 纳入可用通道诊断集合
            for tool in tools where tool.isInstalled {
                self.enabledAgentIds.insert(tool.id)
            }
            self.isDetectingEnv = false
        }
    }
}
