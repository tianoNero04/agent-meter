import SwiftUI
import Charts

/// 平面构成主义主面板容器：承载三大结构化网格模块（身份标牌、额度标尺、Token账本）
struct ProviderPanel: View {
    let snapshot: ProviderSnapshot
    let refresh: () -> Void
    var slideEdge: Edge = .trailing

    private var removalEdge: Edge { slideEdge == .trailing ? .leading : .trailing }

    var body: some View {
        VStack(spacing: 7) {
            // 模块 01：Agent 身份与计划档次
            ProviderHeroCard(snapshot: snapshot)
            // 模块 02：额度仪表与精密刻度标尺
            QuotaCard(snapshot: snapshot, refresh: refresh)
            // 模块 03：算力消耗与 7 日动态趋势账本
            TokenUsageCard(snapshot: snapshot)
        }
        .id(snapshot.provider)
        .transition(.asymmetric(
            insertion: .move(edge: slideEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        ))
    }
}

/// 模块 01：Provider 身份与订阅计划标牌（构成主义微圆角与荧光绿 TIER 高光）
struct ProviderHeroCard: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        HStack(spacing: 12) {
            // 纯黑微方块图标底衬
            ProviderIconTile(provider: snapshot.provider, size: 44)

            // 粗壮无衬线标题与构成主义状态码
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("[01 // NODE]")
                        .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.secondaryText.opacity(0.8))
                }

                Text(snapshot.provider.displayName.uppercased())
                    .font(.system(size: 16, weight: .heavy, design: .default))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.primaryText)

                HStack(spacing: 6) {
                    StatusBadge(status: snapshot.status)
                    if let error = snapshot.errorMessage {
                        Text("PREV.DATA · \(error)")
                            .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.warning)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 构成主义 Plan 架构标签（荧光绿发丝边框与荧光绿文字）
            VStack(alignment: .trailing, spacing: 2) {
                Text("TIER // PLAN")
                    .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(planLabel)
                    .font(.system(size: 12.5, weight: .heavy, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.neonGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                            .stroke(AppTheme.neonGreenBorder, lineWidth: 0.75)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 74)
        .panelBackground()
    }

    /// 计算当前订阅计划标签
    private var planLabel: String {
        guard let plan = snapshot.account?.planType, !plan.isEmpty else { return "LOCAL" }
        return plan.uppercased()
    }
}

/// 按压微回弹按钮样式
private struct PressBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 模块 02：额度容量与精密刻度标尺面板（带有荧光绿胶囊标尺与校准按钮）
struct QuotaCard: View {
    let snapshot: ProviderSnapshot
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 模块头部栏：标题 + 刷新按钮
            HStack(alignment: .center, spacing: 6) {
                // 荧光绿垂直精密胶囊微标尺
                RoundedRectangle(cornerRadius: 1)
                    .fill(AppTheme.neonGreen)
                    .frame(width: 2.5, height: 11)
                    .shadow(color: AppTheme.neonGreen.opacity(0.6), radius: 2)

                Text("剩余额度")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("QUOTA.MONITOR")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.7))

                Spacer()

                // 校准/刷新触发按钮（荧光绿描边与图标）
                Button(action: refresh) {
                    HStack(spacing: 4) {
                        RefreshIconShape()
                            .fill(AppTheme.neonGreen)
                            .frame(width: 8.5, height: 8.5)
                        Text("CALIBRATE")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(AppTheme.neonGreen)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                            .stroke(AppTheme.neonGreenBorder, lineWidth: 0.75)
                    )
                }
                .buttonStyle(PressBounceButtonStyle())
                .help("刷新账号服务端额度数据 (Calibrate Quotas)")
            }
            .padding(.horizontal, 12)
            .frame(height: 28)

            // 发丝分隔线
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 0.75)
                .padding(.horizontal, 12)

            // 额度行列表 / 空态
            if snapshot.windows.isEmpty {
                QuotaEmptyState(provider: snapshot.provider)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(snapshot.windows) { window in
                        RateLimitRow(window: window)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(height: 154, alignment: .top)
        .panelBackground()
    }
}

/// 模块 03：Token 账本与 7 日算力消耗动态趋势（荧光绿折线与光晕渐变）
struct TokenUsageCard: View {
    let snapshot: ProviderSnapshot

    private var totalTokens: Int { snapshot.accountUsage?.lifetimeTokens ?? snapshot.localTokenUsage.total }
    private var buckets: [DailyTokenBucket] {
        // 优先尝试获取服务端账号 7 日分桶；若服务端分桶无数据或近 7 天滞后为空，自动平滑回退到本地日志分桶
        let accountBuckets = recentSevenDayBuckets(snapshot.accountUsage?.dailyBuckets ?? [])
        if !accountBuckets.isEmpty {
            return accountBuckets
        }
        return recentSevenDayBuckets(snapshot.localDailyBuckets)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 模块索引行（荧光绿胶囊标尺与大写技术题注）
            HStack(alignment: .center, spacing: 6) {
                // 荧光绿垂直精密微标尺
                RoundedRectangle(cornerRadius: 1)
                    .fill(AppTheme.neonGreen)
                    .frame(width: 2.5, height: 11)
                    .shadow(color: AppTheme.neonGreen.opacity(0.6), radius: 2)

                Text("Token 统计")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("TOTAL COMPUTE")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.7))

                Spacer()

                HStack(spacing: 3) {
                    Text("7 日动态趋势")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                // 左侧 Token 计数与细分指标（对齐 cc-switch 指标体系）
                VStack(alignment: .leading, spacing: 3) {
                    Text(formatCompactNumber(totalTokens))
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppTheme.primaryText)

                    // 细分指示：当有缓存命中时显示 Cache Hit Rate（荧光绿强调）；否则显示输入输出细分
                    if snapshot.localTokenUsage.cachedInput > 0 {
                        HStack(spacing: 3) {
                            Text("CACHE")
                                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("\(Int(round(snapshot.localTokenUsage.cacheHitRate * 100)))% HIT")
                                .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(AppTheme.neonGreen)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                    } else if snapshot.localTokenUsage.input > 0 || snapshot.localTokenUsage.output > 0 {
                        HStack(spacing: 3) {
                            Text("IN \(formatCompactNumber(snapshot.localTokenUsage.input))")
                            Text("·")
                            Text("OUT \(formatCompactNumber(snapshot.localTokenUsage.output))")
                        }
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                    }
                }
                .frame(width: 104, alignment: .leading)

                // 竖向发丝分割
                Rectangle()
                    .fill(AppTheme.hairline)
                    .frame(width: 0.75, height: 44)

                // 右侧 7 天趋势网格图表（荧光绿折线与柔和渐变区域）
                if buckets.isEmpty {
                    VStack(spacing: 3) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.tertiaryText)
                        Text("[NO DATA POINTS IN RANGE]")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                } else {
                    Chart(buckets) { bucket in
                        AreaMark(x: .value("DATE", bucket.startDate, unit: .day), y: .value("TOKENS", bucket.tokens))
                            .foregroundStyle(LinearGradient(colors: [AppTheme.neonGreen.opacity(0.32), AppTheme.neonGreen.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("DATE", bucket.startDate, unit: .day), y: .value("TOKENS", bucket.tokens))
                            .foregroundStyle(AppTheme.neonGreen)
                            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("DATE", bucket.startDate, unit: .day), y: .value("TOKENS", bucket.tokens))
                            .foregroundStyle(AppTheme.primaryText)
                            .symbolSize(18)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 98)
        .panelBackground()
    }
}

/// 额度空态指示：极简构成主义结构化未连接占位
struct QuotaEmptyState: View {
    let provider: Provider

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACCOUNT QUOTA")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(quotaSubtitle)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Text("STANDBY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                            .stroke(AppTheme.hairline, lineWidth: 0.5)
                    )
            }

            // 占位分段点阵
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(Color.white.opacity(0.05))
                        .frame(maxWidth: .infinity, maxHeight: 6)
                }
            }

            Text(quotaDescription)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                .fill(AppTheme.background.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 0.75)
                )
        )
    }

    /// 状态标签副标题
    private var quotaSubtitle: String {
        switch provider {
        case .codex: return "UNRESOLVED // READY"
        case .kimiCode: return "CLI ONLY // LOCAL MODE"
        default: return "AGENT READY // LOCAL MODE"
        }
    }

    /// 额度说明描述文本
    private var quotaDescription: String {
        switch provider {
        case .codex:
            return "刷新时从官方通道提取配额，当前尚未获取。"
        case .kimiCode:
            return "Kimi 适配器接入就绪，当前记录本地通道算力。"
        default:
            return "\(provider.displayName) 本地运行环境已就绪，当前处于活动状态。"
        }
    }
}
