import SwiftUI

/// 模型单价与费率矩阵配置面板（仿照 ReactBits Pro data-table-3 设计风格）
/// 支持深色卡片式排版、状态圆点指示器、以及行内可编辑药丸单元格（Inline Editable Pill Cells）
struct ModelPricingTab: View {
    @ObservedObject var model: DashboardModel
    @State private var preferences: PricingPreferences
    @State private var isCheckingUpdates = false
    @State private var updateMessage: String?
    @State private var hoveredModelId: String?

    private let store: PricingSettingsStore

    init(model: DashboardModel, store: PricingSettingsStore = UserDefaultsPricingSettingsStore()) {
        self.model = model
        self.store = store
        self._preferences = State(initialValue: store.load())
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // 顶栏刊头标示
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.codex)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("模型费率与成本换算")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("PRICING // DATA.TABLE.V3")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    Spacer()
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

                // 主数据表格卡片（严格复刻 ReactBits Pro data-table-3）
                VStack(alignment: .leading, spacing: 0) {
                    // 表格头部栏 (Card Header)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("模型费率矩阵与实时换算")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)

                            Text("点击单价药丸单元格可直接行内调整 · 支持实时换算与乐观保存")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(AppTheme.tertiaryText)
                        }

                        Spacer()

                        // 检查最新模型定价按钮
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

                                Text(isCheckingUpdates ? "同步中..." : "检查最新模型定价")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(white: 0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isCheckingUpdates)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                    Divider()
                        .background(Color.white.opacity(0.08))

                    // 表头字段列 (Table Column Headers)
                    HStack(spacing: 10) {
                        Text("模型名称 / MODEL")
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("服务商")
                            .frame(width: 78, alignment: .leading)

                        Text("状态")
                            .frame(width: 78, alignment: .leading)

                        Text("输入 (1M)")
                            .frame(width: 76, alignment: .center)

                        Text("缓存 (1M)")
                            .frame(width: 76, alignment: .center)

                        Text("输出 (1M)")
                            .frame(width: 76, alignment: .center)

                        Text("")
                            .frame(width: 24, alignment: .center)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.015))

                    Divider()
                        .background(Color.white.opacity(0.08))

                    // 表格数据行列表 (Table Data Rows)
                    VStack(spacing: 0) {
                        ForEach(displayedPricings) { pricingItem in
                            tableRow(for: pricingItem)

                            if pricingItem.id != displayedPricings.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.05))
                            }
                        }
                    }
                }
                .background(Color(red: 14/255, green: 16/255, blue: 21/255))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
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

    // MARK: - 单行渲染
    private func tableRow(for item: ModelPricing) -> some View {
        let isCustomized = isLocallyCustomized(item)
        let providerName = detectProviderName(for: item.modelName)
        let isHovered = hoveredModelId == item.id

        return HStack(spacing: 10) {
            // 1. 模型标识（等宽粗体白字）
            Text(item.modelName)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 2. 服务商列
            Text(providerName)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 78, alignment: .leading)

            // 3. 状态列（对齐 ReactBits 圆点指示器）
            HStack(spacing: 5) {
                Circle()
                    .fill(isCustomized ? Color(red: 251/255, green: 146/255, blue: 60/255) : Color(red: 74/255, green: 222/255, blue: 128/255))
                    .frame(width: 6, height: 6)

                Text(isCustomized ? "已自定义" : "官方预设")
                    .font(.system(size: 11, weight: isCustomized ? .medium : .regular))
                    .foregroundStyle(isCustomized ? AppTheme.primaryText : AppTheme.secondaryText)
            }
            .frame(width: 78, alignment: .leading)

            // 4. 输入单价药丸单元格
            InlineEditablePillCell(
                value: item.inputPerMillion,
                symbol: item.baseCurrency.symbol,
                width: 76
            ) { newPrice in
                updatePrice(for: item, input: newPrice)
            }

            // 5. 缓存读取单价药丸单元格
            InlineEditablePillCell(
                value: item.cacheReadPerMillion,
                symbol: item.baseCurrency.symbol,
                isCache: true,
                width: 76
            ) { newPrice in
                updatePrice(for: item, cache: newPrice)
            }

            // 6. 输出单价药丸单元格
            InlineEditablePillCell(
                value: item.outputPerMillion,
                symbol: item.baseCurrency.symbol,
                width: 76
            ) { newPrice in
                updatePrice(for: item, output: newPrice)
            }

            // 7. 重置操作按钮（仅在自定义时显示撤销按钮）
            ZStack {
                if isCustomized {
                    Button {
                        resetToDefault(for: item)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("恢复为官方预设单价")
                }
            }
            .frame(width: 24, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovered ? Color.white.opacity(0.025) : Color.clear)
        .onHover { hovered in
            hoveredModelId = hovered ? item.id : nil
        }
    }

    // MARK: - 辅助计算与操作
    private func isLocallyCustomized(_ item: ModelPricing) -> Bool {
        let key = item.modelName.lowercased()
        guard let custom = preferences.customPricings[key] else { return false }
        guard let defaultPreset = DefaultModelPricings.presets.first(where: { $0.modelName.lowercased() == key }) else {
            return true
        }
        return custom.inputPerMillion != defaultPreset.inputPerMillion ||
               custom.cacheReadPerMillion != defaultPreset.cacheReadPerMillion ||
               custom.outputPerMillion != defaultPreset.outputPerMillion
    }

    private func detectProviderName(for modelName: String) -> String {
        let clean = modelName.lowercased()
        if clean.hasPrefix("gpt-") || clean.hasPrefix("o1") || clean.hasPrefix("o3") {
            return "OpenAI"
        }
        if clean.hasPrefix("kimi-") || clean.hasPrefix("moonshot-") {
            return "Moonshot"
        }
        if clean.hasPrefix("claude-") {
            return "Anthropic"
        }
        if clean.hasPrefix("deepseek-") {
            return "DeepSeek"
        }
        if clean.hasPrefix("grok-") {
            return "xAI"
        }
        return "通用"
    }

    private func updatePrice(for item: ModelPricing, input: Double? = nil, cache: Double? = nil, output: Double? = nil) {
        let key = item.modelName.lowercased()
        var current = preferences.customPricings[key] ?? item
        if let input = input { current.inputPerMillion = max(0, input) }
        if let cache = cache { current.cacheReadPerMillion = max(0, cache) }
        if let output = output { current.outputPerMillion = max(0, output) }

        preferences.customPricings[key] = current
        save()
    }

    private func resetToDefault(for item: ModelPricing) {
        let key = item.modelName.lowercased()
        preferences.customPricings.removeValue(forKey: key)
        save()
    }

    /// 聚合用于展示的全部模型列表（严格基于规范名称去重，按字母升序排列）
    private var displayedPricings: [ModelPricing] {
        var map: [String: ModelPricing] = [:]

        // 1. 先加入内置规范预设
        for p in DefaultModelPricings.presets {
            let canonical = DefaultModelPricings.normalizeModelName(p.modelName)
            var item = p
            item.modelName = canonical
            map[canonical] = item
        }

        // 2. 再用自定义/最新同步覆盖
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

/// 仿照 ReactBits Pro data-table-3 的行内可编辑深色药丸单元格组件
struct InlineEditablePillCell: View {
    let value: Double
    let symbol: String
    var isCache: Bool = false
    var width: CGFloat = 76

    var onCommit: (Double) -> Void

    @State private var isEditing = false
    @State private var textInput = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            if isEditing {
                TextField("", text: $textInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .focused($isFocused)
                    .onSubmit {
                        commitChange()
                    }
                    .onChange(of: isFocused) { focused in
                        if !focused {
                            commitChange()
                        }
                    }
            } else {
                HStack(spacing: 2) {
                    Text(symbol)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(isCache ? AppTheme.codex.opacity(0.85) : AppTheme.tertiaryText)

                    Text(formattedValue(value))
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isCache ? AppTheme.codex : AppTheme.primaryText)
                }
            }
        }
        .frame(width: width, height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isEditing ? Color(white: 0.20) : Color(white: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isEditing ? AppTheme.codex : Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            textInput = String(format: "%.3f", value).replacingOccurrences(of: "0+$", with: "", options: .regularExpression).replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
            isEditing = true
            isFocused = true
        }
    }

    private func commitChange() {
        if let parsed = Double(textInput) {
            onCommit(parsed)
        }
        isEditing = false
        isFocused = false
    }

    private func formattedValue(_ val: Double) -> String {
        if val == 0 { return "0.00" }
        if val < 0.01 {
            return String(format: "%.4f", val)
        } else if val < 1.0 {
            return String(format: "%.3f", val).replacingOccurrences(of: "0$", with: "", options: .regularExpression)
        } else {
            return String(format: "%.2f", val)
        }
    }
}
