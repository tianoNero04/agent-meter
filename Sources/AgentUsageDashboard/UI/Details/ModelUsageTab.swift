import SwiftUI

/// 现代深色模型消耗排行与账单对账看板
struct ModelUsageTab: View {
    @ObservedObject var model: DashboardModel
    @State private var selectedProviderState: Provider? = nil
    @State private var preferences: PricingPreferences

    private let store: PricingSettingsStore

    init(model: DashboardModel, store: PricingSettingsStore = UserDefaultsPricingSettingsStore()) {
        self.model = model
        self.store = store
        self._preferences = State(initialValue: store.load())
    }

    /// 当前激活查看的提供商（优先取手动选择，其次取全局选择，默认 Codex）
    private var activeProvider: Provider {
        if let s = selectedProviderState, model.navigation.visibleProviders.contains(s) {
            return s
        }
        return model.navigation.selectedProvider ?? model.navigation.visibleProviders.first ?? .codex
    }

    /// 当前服务商快照
    private var snapshot: ProviderSnapshot {
        model.snapshot(for: activeProvider)
    }

    /// 排序后的模型列表（按 Token 消耗总量降序排列）
    private var sortedModels: [ModelUsage] {
        snapshot.localModels.sorted { $0.usage.total > $1.usage.total }
    }

    /// 本机观测总 Token
    private var totalLocalTokens: Int {
        sortedModels.reduce(0) { $0 + $1.usage.total }
    }

    /// 账号云端总 Token（若有数据）
    private var totalAccountTokens: Int? {
        snapshot.accountUsage?.lifetimeTokens
    }

    /// 加权估算总支出金额
    private var totalEstimatedCost: Double {
        sortedModels.reduce(0.0) { sum, item in
            let pricing = preferences.pricing(for: item.model)
            return sum + pricing.calculateCost(
                for: item.usage,
                targetCurrency: preferences.targetCurrency,
                exchangeRate: preferences.usdToCnyRate
            )
        }
    }

    /// 总体缓存命中率
    private var overallCacheHitRate: Double {
        let totalInputAndCache = sortedModels.reduce(0) { $0 + $1.usage.input + $1.usage.cachedInput }
        guard totalInputAndCache > 0 else { return 0.0 }
        let totalCache = sortedModels.reduce(0) { $0 + $1.usage.cachedInput }
        return Double(totalCache) / Double(totalInputAndCache)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // 1. 顶栏刊头标示与 Provider 切换器
                headerView

                // 2. 核心 KPI 指标卡组（4 栏网格）
                kpiSummaryCardsView

                // 3. 模型消耗排行矩阵大卡片
                rankingLeaderboardCardView

                // 4. 对账机制与数据边界卡片
                reconciliationNoticeCardView

                Spacer(minLength: 24)
            }
            .padding(.top, 44)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            preferences = store.load()
            if selectedProviderState == nil {
                selectedProviderState = model.navigation.selectedProvider
            }
        }
    }

    // MARK: - 子视图：顶栏刊头
    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.codex)

                VStack(alignment: .leading, spacing: 1) {
                    Text("模型消耗排行与账单对账")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("RANKING & RECONCILIATION // LOCAL LOGS VS ACCOUNT")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }

            Spacer()

            // 快捷服务商切换胶囊（仅在有多个启用的服务商时显示）
            if model.navigation.visibleProviders.count > 1 {
                HStack(spacing: 3) {
                    ForEach(model.navigation.visibleProviders, id: \.self) { provider in
                        let isSelected = provider == activeProvider
                        Button {
                            selectedProviderState = provider
                        } label: {
                            Text(provider.displayName)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.hairline, lineWidth: 0.75))
                )
            } else {
                Text(activeProvider.displayName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.hairline, lineWidth: 0.75))
                    )
            }
        }
    }

    // MARK: - 子视图：核心 KPI 指标卡组
    private var kpiSummaryCardsView: some View {
        HStack(spacing: 12) {
            // 卡片 1：活跃模型数
            kpiCard(
                title: "活跃模型种类",
                mainText: "\(sortedModels.count)",
                unitText: "款",
                subText: "基于本机日志实时捕获",
                highlightColor: AppTheme.primaryText
            )

            // 卡片 2：本机观测总 Tokens
            kpiCard(
                title: "本机观测总 Tokens",
                mainText: formatTokens(totalLocalTokens),
                unitText: nil,
                subText: "缓存命中率 \(formatPercent(overallCacheHitRate))",
                highlightColor: AppTheme.primaryText
            )

            // 卡片 3：加权估算总支出
            kpiCard(
                title: "估算加权总花费",
                mainText: String(format: "%.2f", totalEstimatedCost),
                unitText: preferences.targetCurrency.symbol,
                isPrefixUnit: true,
                subText: "折合 \(preferences.targetCurrency.rawValue)",
                highlightColor: AppTheme.codex
            )

            // 卡片 4：云端账单对账覆盖度
            let (covText, covSub) = calculateCoverageInfo()
            kpiCard(
                title: "账号对账覆盖率",
                mainText: covText,
                unitText: nil,
                subText: covSub,
                highlightColor: AppTheme.success
            )
        }
    }

    private func kpiCard(
        title: String,
        mainText: String,
        unitText: String?,
        isPrefixUnit: Bool = false,
        subText: String,
        highlightColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if isPrefixUnit, let unit = unitText {
                    Text(unit)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(highlightColor)
                }

                Text(mainText)
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(highlightColor)

                if !isPrefixUnit, let unit = unitText {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }

            Text(subText)
                .font(.system(size: 9.5, weight: .regular))
                .foregroundStyle(AppTheme.tertiaryText)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                        .stroke(AppTheme.hairline, lineWidth: 0.75)
                )
        )
    }

    private func calculateCoverageInfo() -> (String, String) {
        if let acc = totalAccountTokens, acc > 0 {
            let ratio = (Double(totalLocalTokens) / Double(acc)) * 100
            let ratioClamped = min(ratio, 100.0)
            let text = String(format: "%.1f%%", ratioClamped)
            let diff = acc - totalLocalTokens
            if diff > 0 {
                return (text, "其他端/未入志 \(formatTokens(diff))")
            } else {
                return (text, "完全覆盖账号账单")
            }
        }
        return ("本机独占", "账号接口未提供全量指标")
    }

    // MARK: - 子视图：模型消耗排行矩阵大卡片
    private var rankingLeaderboardCardView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片表头
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本机模型用量排行榜")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("按实际调用 Token 降序排列 · 包含构成分布、单价核算与用量份额")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                Spacer()

                Text("\(sortedModels.count) 款模型")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(14)

            Divider()
                .background(AppTheme.hairline)

            if sortedModels.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.tertiaryText)
                        Text("暂无 \(activeProvider.displayName) 的本机模型日志记录")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .padding(.vertical, 36)
                    Spacer()
                }
            } else {
                // 表头列名
                HStack(spacing: 12) {
                    Text("排名 / 模型名称")
                        .frame(width: 170, alignment: .leading)

                    Text("Token 构成分布 (输入 / 缓存 / 输出)")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("份额占比")
                        .frame(width: 80, alignment: .trailing)

                    Text("估算费用")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.02))

                Divider()
                    .background(AppTheme.hairline)

                // 模型数据列表行
                VStack(spacing: 0) {
                    ForEach(Array(sortedModels.enumerated()), id: \.element.id) { index, item in
                        modelRowView(index: index + 1, item: item)

                        if index < sortedModels.count - 1 {
                            Divider()
                                .background(AppTheme.hairline.opacity(0.5))
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                        .stroke(AppTheme.hairline, lineWidth: 0.75)
                )
        )
    }

    // MARK: - 子视图：单个模型行
    private func modelRowView(index: Int, item: ModelUsage) -> some View {
        let pricing = preferences.pricing(for: item.model)
        let cost = pricing.calculateCost(
            for: item.usage,
            targetCurrency: preferences.targetCurrency,
            exchangeRate: preferences.usdToCnyRate
        )
        let sharePercent = totalLocalTokens > 0 ? (Double(item.usage.total) / Double(totalLocalTokens)) : 0.0

        return HStack(spacing: 12) {
            // 1. 排名与模型信息
            HStack(spacing: 8) {
                // 排名 Badge
                Text("#\(index)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(index <= 3 ? AppTheme.codex : AppTheme.tertiaryText)
                    .frame(width: 24, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index <= 3 ? AppTheme.codex.opacity(0.15) : Color.white.opacity(0.04))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.model)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)

                    Text(detectProviderName(for: item.model))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .frame(width: 170, alignment: .leading)

            // 2. Token 三段式构成条与细分数值
            VStack(alignment: .leading, spacing: 4) {
                // 构成比例条
                TokenStackedBar(usage: item.usage)
                    .frame(height: 5)
                    .clipShape(Capsule())

                // 细分数据描述
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Circle().fill(Color(red: 0.20, green: 0.45, blue: 0.90)).frame(width: 4.5, height: 4.5)
                        Text("输入 \(formatTokens(item.usage.input))")
                    }

                    HStack(spacing: 3) {
                        Circle().fill(AppTheme.codex).frame(width: 4.5, height: 4.5)
                        Text("缓存 \(formatTokens(item.usage.cachedInput)) (\(formatPercent(item.usage.cacheHitRate)))")
                    }

                    HStack(spacing: 3) {
                        Circle().fill(Color(red: 0.55, green: 0.35, blue: 0.85)).frame(width: 4.5, height: 4.5)
                        Text("输出 \(formatTokens(item.usage.output))")
                    }

                    Spacer()

                    Text("总计 \(formatTokens(item.usage.total))")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .font(.system(size: 9.5, weight: .regular))
                .foregroundStyle(AppTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 3. 份额占比
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.1f%%", sharePercent * 100))
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.primaryText)

                // 迷你占比槽位
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                        Capsule()
                            .fill(AppTheme.codex)
                            .frame(width: geo.size.width * CGFloat(sharePercent))
                    }
                }
                .frame(width: 48, height: 3.5)
            }
            .frame(width: 80, alignment: .trailing)

            // 4. 估算费用
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%@%.2f", preferences.targetCurrency.symbol, cost))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(cost > 0 ? AppTheme.primaryText : AppTheme.tertiaryText)

                Text(preferences.targetCurrency.rawValue)
                    .font(.system(size: 8.5, weight: .regular))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 子视图：对账机制与数据边界卡片
    private var reconciliationNoticeCardView: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.codex)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                Text("数据边界与对账机制说明")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• 本机日志观测口径")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("通过流式解析当前 Mac 本地会话日志精确到每一条交互，是模型消耗细分、缓存命中率以及加权费率计算的真实依据。")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("• 云端账号汇总口径")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("官方服务端接口返回的全账号用量。若本机 Token 占账号总量比例偏低，通常因同账号在多设备共用或本地历史日志已轮转。")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                .fill(AppTheme.surface.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                        .stroke(AppTheme.hairline, lineWidth: 0.75)
                )
        )
    }

    // MARK: - 辅助工具
    /// 识别模型归属的厂商名称
    private func detectProviderName(for modelName: String) -> String {
        let clean = modelName.lowercased()
        if clean.contains("gpt") || clean.contains("o1") || clean.contains("o3") || clean.contains("codex") {
            return "OpenAI"
        }
        if clean.contains("kimi") || clean.contains("moonshot") {
            return "Moonshot"
        }
        if clean.contains("claude") {
            return "Anthropic"
        }
        if clean.contains("deepseek") {
            return "DeepSeek"
        }
        if clean.contains("grok") {
            return "xAI"
        }
        return "通用"
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000.0)
        }
        return "\(count)"
    }

    private func formatPercent(_ rate: Double) -> String {
        String(format: "%.1f%%", rate * 100)
    }
}

/// 模型 Token 组成三色堆叠比例条
struct TokenStackedBar: View {
    let usage: TokenUsage

    var body: some View {
        GeometryReader { geo in
            let total = max(1, usage.total)
            let inputW = (CGFloat(usage.input) / CGFloat(total)) * geo.size.width
            let cacheW = (CGFloat(usage.cachedInput) / CGFloat(total)) * geo.size.width
            let outputW = (CGFloat(usage.output) / CGFloat(total)) * geo.size.width

            HStack(spacing: 0) {
                // 1. 输入部分（深蓝）
                Rectangle()
                    .fill(Color(red: 0.20, green: 0.45, blue: 0.90))
                    .frame(width: inputW)

                // 2. 缓存命中部分（亮青蓝）
                Rectangle()
                    .fill(AppTheme.codex)
                    .frame(width: cacheW)

                // 3. 输出部分（蓝紫）
                Rectangle()
                    .fill(Color(red: 0.55, green: 0.35, blue: 0.85))
                    .frame(width: outputW)
            }
        }
        .background(Color.white.opacity(0.06))
    }
}

