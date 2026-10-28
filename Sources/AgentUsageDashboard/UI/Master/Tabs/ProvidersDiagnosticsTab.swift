import SwiftUI

/// 服务商管理与网络健康测速雷达面板
struct ProvidersDiagnosticsTab: View {
    @ObservedObject var model: DashboardModel
    @Binding var latencyBadge: String?

    @State private var isTesting = false
    @State private var diagnosticResults: [DiagnosticResult] = []

    private let diagnosticsService = NetworkDiagnosticsService()

    /// 本地工具环境列表（直接订阅 model.localTools）
    private var toolEnvironments: [LocalToolEnvironment] {
        model.localTools
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
                        .foregroundStyle(AppTheme.accent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("服务商与网络健康诊断")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
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

                VStack(spacing: 12) {
                    if model.isDetectingEnv {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("正在检测本机客户端；已登录凭据仍可用于账号查询")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    ForEach(Provider.supportedProviders, id: \.self) { provider in
                        let tool = toolEnvironments.first { $0.id == provider.toolId }
                        unifiedProviderCard(
                            for: provider,
                            name: provider.displayName,
                            vendor: tool?.vendor ?? provider.vendorName,
                            version: tool?.version,
                            location: tool?.locationPath ?? tool?.statusDescription ?? "未检测到客户端；可尝试本机登录凭据",
                            iconName: tool?.iconName ?? provider.iconName,
                            isInstalled: tool?.isInstalled ?? false
                        )
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
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
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
                                        .font(.system(size: 11, weight: .regular))
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
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            if toolEnvironments.isEmpty {
                model.inspectEnvironment()
            }
        }
    }

    private func unifiedProviderCard(
        for provider: Provider,
        name: String,
        vendor: String,
        version: String?,
        location: String,
        iconName: String,
        isInstalled: Bool
    ) -> some View {
        let isEnabled = model.navigation.isEnabled(provider)

        return HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isInstalled ? AppTheme.accent : AppTheme.tertiaryText)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(name) (\(vendor))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    if let version {
                        Text(version)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.success)
                    } else {
                        Text(isInstalled ? "已安装" : "未检测到")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                Text(location)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .help(location)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { model.setProviderEnabled(provider, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .accessibilityLabel("在菜单栏显示 \(provider.displayName)")
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

    /// 触发单次按需测速（覆盖当前在本地已检测出且已启用的服务商通道）
    private func runDiagnostics() {
        guard !isTesting else { return }
        isTesting = true
        diagnosticResults = []
        latencyBadge = nil

        Task { @MainActor in
            var targets: [(id: String, name: String, url: URL)] = []

            // 遍历所有已在本地检测出且当前处于开启状态的 Provider
            for provider in Provider.allCases where model.navigation.isEnabled(provider) {
                if let ep = NetworkDiagnosticsService.knownEndpoints[provider.toolId] {
                    targets.append((id: provider.toolId, name: ep.name, url: ep.url))
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

            let successful = results.filter(\.isSuccess)
            if successful.isEmpty {
                self.latencyBadge = "—"
            } else {
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
                        .foregroundStyle(AppTheme.accent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("本地 Agent 运行环境检测")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("已安装的工具")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }

                Spacer()

                // 一键环境检测按钮
                Button {
                    model.inspectEnvironment()
                } label: {
                    HStack(spacing: 5) {
                        if model.isDetectingEnv {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(model.isDetectingEnv ? "探测中..." : "一键环境检测")
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
                .disabled(model.isDetectingEnv)
            }

            if toolEnvironments.isEmpty && !model.isDetectingEnv {
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
                                .foregroundStyle(tool.isInstalled ? AppTheme.accent : AppTheme.tertiaryText)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(tool.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.primaryText)

                                    Text(tool.vendor)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(AppTheme.tertiaryText)

                                    if let ver = tool.version {
                                        Text(ver)
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
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
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .lineLimit(1)
                                } else {
                                    Text(tool.statusDescription)
                                        .font(.system(size: 11, weight: .regular))
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
                            RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
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
}
