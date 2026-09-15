import SwiftUI

/// 模型单价与费率矩阵配置面板
struct ModelPricingTab: View {
    @ObservedObject var model: DashboardModel
    @State private var preferences: PricingPreferences
    @State private var isCheckingUpdates = false
    @State private var updateMessage: String?

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
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.codex)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("模型费率与成本换算")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("PRICING // MATRIX.CONVERSION")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    Spacer()

                    // 检查最新模型定价按钮（按需触发，零后台轮询）
                    Button {
                        checkForUpdates()
                    } label: {
                        HStack(spacing: 5) {
                            if isCheckingUpdates {
                                ProgressView()
                                    .scaleEffect(0.65)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11, weight: .semibold))
                            }

                            Text(isCheckingUpdates ? "更新中..." : "检查最新模型定价")
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
                    .disabled(isCheckingUpdates)
                }

                if let updateMessage {
                    Text(updateMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.success)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.success.opacity(0.1))
                        )
                }

                // 货币与汇率控制卡片
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("结算展示币种")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)

                        Picker("", selection: $preferences.targetCurrency) {
                            ForEach(PricingCurrency.allCases) { currency in
                                Text(currency.displayName).tag(currency)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                        .onChange(of: preferences.targetCurrency) { _ in save() }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("美元/人民币汇率基准")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)

                        HStack(spacing: 6) {
                            Text("1 USD =")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(AppTheme.secondaryText)

                            TextField("7.20", value: $preferences.usdToCnyRate, format: .number)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.primaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(width: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AppTheme.surface)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.hairline, lineWidth: 0.75))
                                )
                                .onSubmit { save() }

                            Text("CNY")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.secondaryText)
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

                // 模型定价预设表格卡片
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("模型官方单价矩阵 (每 100 万 Tokens)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Text("输入 / 缓存读取 / 输出")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    VStack(spacing: 8) {
                        ForEach(displayedPricings) { pricingItem in
                            HStack {
                                Text(pricingItem.modelName)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AppTheme.primaryText)

                                Spacer()

                                HStack(spacing: 12) {
                                    pricingTag(label: "入", amount: pricingItem.inputPerMillion, symbol: pricingItem.baseCurrency.symbol)
                                    pricingTag(label: "缓", amount: pricingItem.cacheReadPerMillion, symbol: pricingItem.baseCurrency.symbol, isCache: true)
                                    pricingTag(label: "出", amount: pricingItem.outputPerMillion, symbol: pricingItem.baseCurrency.symbol)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.background.opacity(0.6))
                            )
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
            .padding(.top, 44)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            preferences = store.load()
        }
    }

    /// 聚合用于展示的全部模型列表（基于规范名称严格去重，纯净展示且按字母排序）
    private var displayedPricings: [ModelPricing] {
        var map: [String: ModelPricing] = [:]

        // 1. 先加入内置规范预设
        for p in DefaultModelPricings.presets {
            let canonical = DefaultModelPricings.normalizeModelName(p.modelName)
            var item = p
            item.modelName = canonical
            map[canonical] = item
        }

        // 2. 再用自定义/最新同步覆盖（键同样使用规范名称）
        for (_, p) in preferences.customPricings {
            let canonical = DefaultModelPricings.normalizeModelName(p.modelName)
            var item = p
            item.modelName = canonical
            map[canonical] = item
        }

        return Array(map.values).sorted { a, b in
            a.modelName.localizedStandardCompare(b.modelName) == .orderedAscending
        }
    }

    private func pricingTag(label: String, amount: Double, symbol: String, isCache: Bool = false) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(isCache ? AppTheme.codex : AppTheme.tertiaryText)

            Text(String(format: "%@%.2f", symbol, amount))
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private func save() {
        store.save(preferences)
    }

    /// 触发真实在线同步并即时刷新界面
    private func checkForUpdates() {
        isCheckingUpdates = true
        updateMessage = nil

        Task { @MainActor in
            do {
                let result = try await ModelPricingSyncService.shared.syncAndSave(store: store)
                self.preferences = store.load()
                self.isCheckingUpdates = false
                let timeStr = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                self.updateMessage = "✓ 已成功同步最新模型定价：已拉取 \(result.totalCount) 款模型 (更新 \(result.updatedCount) 项，时间 \(timeStr))"
            } catch {
                self.isCheckingUpdates = false
                self.updateMessage = "⚠ 同步 models.dev 异常：\(error.localizedDescription)，已保留本地最新预设费率"
            }
        }
    }
}
