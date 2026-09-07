import SwiftUI

/// 服务商管理与网络健康测速雷达面板
struct ProvidersDiagnosticsTab: View {
    @ObservedObject var model: DashboardModel
    @Binding var latencyBadge: String?

    @State private var isTesting = false
    @State private var diagnosticResults: [DiagnosticResult] = []

    private let diagnosticsService = NetworkDiagnosticsService()

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

                // 服务商卡片列表
                VStack(spacing: 12) {
                    providerCard(for: .codex, title: "Codex (OpenAI)", credentialHint: "读取 Keychain 或 ~/.codex/auth.json")
                    providerCard(for: .kimiCode, title: "Kimi Code (Moonshot)", credentialHint: "读取 ~/.kimi-code/credentials/kimi-code.json")
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

                Spacer(minLength: 20)
            }
            .padding(.top, 44)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
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

    /// 触发单次按需测速
    private func runDiagnostics() {
        guard !isTesting else { return }
        isTesting = true

        Task { @MainActor in
            let results = await diagnosticsService.runFullDiagnostics()
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
}
