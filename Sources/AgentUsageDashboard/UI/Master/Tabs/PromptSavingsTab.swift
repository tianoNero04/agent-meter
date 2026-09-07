import SwiftUI

/// Prompt Caching 缓存省钱感知看板与模型对账面板
struct PromptSavingsTab: View {
    @ObservedObject var model: DashboardModel
    @State private var preferences: PricingPreferences

    private let store: PricingSettingsStore

    init(model: DashboardModel, store: PricingSettingsStore = UserDefaultsPricingSettingsStore()) {
        self.model = model
        self.store = store
        self._preferences = State(initialValue: store.load())
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // 顶栏刊头标示
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.codex)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Prompt Caching 缓存省钱感知")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("SAVINGS // CACHE.EFFICIENCY")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    Spacer()

                    // 右上角日夜模式切换图标
                    ThemeToggleButton()
                }

                // 核心省钱高亮看板
                HStack(spacing: 14) {
                    // 省钱金额大卡片
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prompt Caching 为您节省")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(preferences.targetCurrency.symbol)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.codex)

                            Text(String(format: "%.2f", totalSavings))
                                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                                .foregroundStyle(AppTheme.primaryText)
                        }

                        Text("基于官方上下文缓存折扣折算 · 纯本地毫秒级计算")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                            .fill(AppTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.gridCornerRadius)
                                    .stroke(AppTheme.codex.opacity(0.3), lineWidth: 0.75)
                            )
                    )

                    // 估算总花费大卡片
                    VStack(alignment: .leading, spacing: 6) {
                        Text("当前观测估算总支出")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(preferences.targetCurrency.symbol)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.secondaryText)

                            Text(String(format: "%.2f", totalCost))
                                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                                .foregroundStyle(AppTheme.primaryText)
                        }

                        Text("已抵扣缓存优惠后的净支出估算")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .padding(16)
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

                // 各模型对账明细列表
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("模型消耗与费用明细对账")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Text("模型 / 缓存命中率 / 估算花费")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    if modelUsageList.isEmpty {
                        HStack {
                            Spacer()
                            Text("当前暂无模型日志记录")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(AppTheme.tertiaryText)
                                .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 8) {
                            ForEach(modelUsageList) { item in
                                let pricing = preferences.pricing(for: item.model)
                                let cost = pricing.calculateCost(
                                    for: item.usage,
                                    targetCurrency: preferences.targetCurrency,
                                    exchangeRate: preferences.usdToCnyRate
                                )

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.model)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(AppTheme.primaryText)

                                        Text("总计: \(formatTokens(item.usage.total)) · 缓存命中: \(formatPercent(item.usage.cacheHitRate))")
                                            .font(.system(size: 10, weight: .regular))
                                            .foregroundStyle(AppTheme.tertiaryText)
                                    }

                                    Spacer()

                                    Text(String(format: "%@%.2f", preferences.targetCurrency.symbol, cost))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(AppTheme.primaryText)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AppTheme.background.opacity(0.6))
                                )
                            }
                        }
                    }
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

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .onAppear {
            preferences = store.load()
        }
    }

    /// 当前所有可观测模型的列表
    private var modelUsageList: [ModelUsage] {
        let currentProvider = model.navigation.selectedProvider ?? .codex
        return model.snapshot(for: currentProvider).localModels
    }

    /// 累计节省金额
    private var totalSavings: Double {
        modelUsageList.reduce(0.0) { sum, item in
            let pricing = preferences.pricing(for: item.model)
            return sum + pricing.calculateCacheSavings(
                for: item.usage,
                targetCurrency: preferences.targetCurrency,
                exchangeRate: preferences.usdToCnyRate
            )
        }
    }

    /// 累计估算支出
    private var totalCost: Double {
        modelUsageList.reduce(0.0) { sum, item in
            let pricing = preferences.pricing(for: item.model)
            return sum + pricing.calculateCost(
                for: item.usage,
                targetCurrency: preferences.targetCurrency,
                exchangeRate: preferences.usdToCnyRate
            )
        }
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
