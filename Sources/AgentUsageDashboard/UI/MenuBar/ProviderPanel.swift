import SwiftUI
import Charts

/// 瑞士网格主面板容器：承载三大结构化网格模块（身份标牌、额度标尺、Token账本）
struct ProviderPanel: View {
    let snapshot: ProviderSnapshot
    let refresh: () -> Void
    var slideEdge: Edge = .trailing

    private var removalEdge: Edge { slideEdge == .trailing ? .leading : .trailing }

    var body: some View {
        VStack(spacing: 8) {
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

/// 模块 01：Provider 身份与订阅计划标牌
struct ProviderHeroCard: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 杂志索引行
            HStack {
                Text("[01 // AGENT.IDENT]")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Text("ENGINE ARCHITECTURE")
                    .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            HStack(spacing: 12) {
                // 几何图标方块
                ProviderIconTile(provider: snapshot.provider, size: 44)

                // 粗壮无衬线标题与状态码
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.provider.displayName.uppercased())
                        .font(.system(size: 16, weight: .heavy, design: .default))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.primaryText)
                    StatusBadge(status: snapshot.status)
                    if let error = snapshot.errorMessage {
                        Text("PREV.DATA · \(error)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.warning)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // 工业风 Plan 架构标签
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIER // PLAN")
                        .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(planLabel)
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(AppTheme.hairlineBright, lineWidth: 0.75)
                        )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(height: 78)
        .panelBackground()
    }

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

/// 模块 02：额度容量与精密刻度标尺面板
struct QuotaCard: View {
    let snapshot: ProviderSnapshot
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 模块头部栏：索引号 + 刷新按钮
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("[02 // RATE.LIMITS]")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("CAPACITY REGISTER")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(AppTheme.primaryText)
                }
                Spacer()

                // 校准/刷新触发按钮
                Button(action: refresh) {
                    HStack(spacing: 4) {
                        RefreshIconShape()
                            .fill(AppTheme.primaryText)
                            .frame(width: 8.5, height: 8.5)
                        Text("CALIBRATE")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(AppTheme.hairlineBright, lineWidth: 0.5)
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
                    .frame(height: rowRegionHeight)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(snapshot.windows.enumerated()), id: \.element.id) { index, window in
                        RateLimitRow(window: window)
                            .padding(.horizontal, 12)
                            .frame(height: rowHeight(at: index))

                        if window.id != snapshot.windows.last?.id {
                            Rectangle()
                                .fill(AppTheme.hairline.opacity(0.6))
                                .frame(height: 0.5)
                                .padding(.horizontal, 12)
                        }
                    }
                }
            }
        }
        .frame(height: 165, alignment: .top)
        .panelBackground()
    }

    private var rowRegionHeight: CGFloat { 165 - 28 - 0.75 }

    private func rowHeight(at index: Int) -> CGFloat {
        guard snapshot.windows.count > 1 else { return rowRegionHeight }
        let totalSeparators: CGFloat = CGFloat(snapshot.windows.count - 1) * 0.5
        return (rowRegionHeight - totalSeparators) / CGFloat(snapshot.windows.count)
    }
}

/// 模块 03：Token 账本与 7 日算力消耗动态趋势（对齐 cc-switch 用量指标）
struct TokenUsageCard: View {
    let snapshot: ProviderSnapshot

    private var totalTokens: Int { snapshot.accountUsage?.lifetimeTokens ?? snapshot.localTokenUsage.total }
    private var buckets: [DailyTokenBucket] {
        let rawBuckets = snapshot.provider == .codex
            ? ((snapshot.accountUsage?.dailyBuckets?.isEmpty == false ? snapshot.accountUsage?.dailyBuckets : nil) ?? snapshot.localDailyBuckets)
            : snapshot.localDailyBuckets
        return recentSevenDayBuckets(rawBuckets)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 模块索引行
            HStack {
                Text("[03 // TOKEN.LEDGER]")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Text("7-DAY DYNAMICS")
                    .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            HStack(alignment: .center, spacing: 12) {
                // 左侧 Token 计数与细分指标（对齐 cc-switch 指标体系）
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatCompactNumber(totalTokens))
                        .font(.system(size: 21, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("TOTAL COMPUTE")
                        .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.secondaryText)

                    // 细分指示：当有缓存命中时显示 Cache Hit Rate；否则显示输入输出细分
                    if snapshot.localTokenUsage.cachedInput > 0 {
                        HStack(spacing: 3) {
                            Text("CACHE")
                                .font(.system(size: 6.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("\(Int(round(snapshot.localTokenUsage.cacheHitRate * 100)))% HIT")
                                .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.codex)
                        }
                    } else if snapshot.localTokenUsage.input > 0 || snapshot.localTokenUsage.output > 0 {
                        HStack(spacing: 3) {
                            Text("IN \(formatCompactNumber(snapshot.localTokenUsage.input))")
                            Text("·")
                            Text("OUT \(formatCompactNumber(snapshot.localTokenUsage.output))")
                        }
                        .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                    }
                }
                .frame(width: 104, alignment: .leading)

                // 竖向发丝分割
                Rectangle()
                    .fill(AppTheme.hairline)
                    .frame(width: 0.75, height: 44)

                // 右侧 7 天趋势网格图表
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
                    .frame(height: 48)
                } else {
                    Chart(buckets) { bucket in
                        AreaMark(x: .value("DATE", bucket.startDate, unit: .day), y: .value("TOKENS", bucket.tokens))
                            .foregroundStyle(LinearGradient(colors: [AppTheme.codex.opacity(0.32), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("DATE", bucket.startDate, unit: .day), y: .value("TOKENS", bucket.tokens))
                            .foregroundStyle(AppTheme.codex)
                            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("DATE", bucket.startDate, unit: .day), y: .value("TOKENS", bucket.tokens))
                            .foregroundStyle(AppTheme.primaryText)
                            .symbolSize(18)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 96)
        .panelBackground()
    }
}

/// 额度空态指示：极简瑞士结构化未连接占位
struct QuotaEmptyState: View {
    let provider: Provider

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACCOUNT QUOTA")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(provider == .kimiCode ? "CLI ONLY // LOCAL MODE" : "UNRESOLVED // READY")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Text("--")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 4)

            Text(provider == .kimiCode ? "Kimi CLI 适配器待接入，当前仅记录本地日志算力。" : "刷新时从 Codex App Server 提取配额，当前尚未获取。")
                .font(.system(size: 7.5, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
    }
}
