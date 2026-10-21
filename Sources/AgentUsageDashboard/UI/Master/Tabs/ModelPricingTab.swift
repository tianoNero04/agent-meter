import SwiftUI

/// 模型单价与费率矩阵配置面板
/// 支持按服务商筛选、行内编辑价格，以及恢复到最近同步的官方价格。
struct ModelPricingTab: View {
    @ObservedObject var model: DashboardModel
    @State private var preferences: PricingPreferences
    @State private var selectedProvider = "全部服务商"
    @State private var isCheckingUpdates = false
    @State private var updateMessage: String?
    @State private var updateErrorDetail: String?
    @State private var hoveredModelId: String?
    @State private var isProviderFilterHovered = false
    @State private var isRefreshHovered = false

    private let store: PricingSettingsStore

    init(model: DashboardModel, store: PricingSettingsStore = UserDefaultsPricingSettingsStore()) {
        self.model = model
        self.store = store
        self._preferences = State(initialValue: store.load())
    }

    var body: some View {
        let pricings = displayedPricings
        let providerNames = Array(Set(pricings.map { PricingProviderClassifier.providerName(for: $0.modelName) })).sorted()
        let visiblePricings = selectedProvider == "全部服务商"
            ? pricings
            : pricings.filter { PricingProviderClassifier.providerName(for: $0.modelName) == selectedProvider }

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("模型费率与成本换算")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                // 主数据表格
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Text("模型定价")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        if let updateMessage {
                            Text(updateMessage)
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineLimit(1)
                                .help(updateErrorDetail ?? updateMessage)
                        }

                        Menu {
                            providerFilterOption("全部服务商")
                            if !providerNames.isEmpty {
                                Divider()
                            }
                            ForEach(providerNames, id: \.self) { provider in
                                providerFilterOption(provider)
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "line.3.horizontal.decrease")
                                    .font(.system(size: 10, weight: .medium))

                                Text(selectedProvider)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .semibold))
                            }
                            .foregroundStyle(isProviderFilterHovered ? AppTheme.primaryText : AppTheme.secondaryText)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(
                                isProviderFilterHovered ? AppTheme.elevated : AppTheme.surface,
                                in: RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                                    .stroke(AppTheme.hairline, lineWidth: 0.75)
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .onHover { isProviderFilterHovered = $0 }
                        .accessibilityLabel("按服务商筛选")
                        .accessibilityValue(selectedProvider)
                        .help("按服务商筛选模型")

                        Button {
                            checkForUpdates()
                        } label: {
                            HStack(spacing: 5) {
                                if isCheckingUpdates {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 12, height: 12)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11, weight: .medium))
                                }

                                Text(isCheckingUpdates ? "同步中" : "检查更新")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(isRefreshHovered ? AppTheme.primaryText : AppTheme.secondaryText)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(
                                isRefreshHovered ? AppTheme.surface : Color.clear,
                                in: RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.geometricRadius, style: .continuous)
                                    .stroke(isRefreshHovered ? AppTheme.hairline : Color.clear, lineWidth: 0.75)
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(isCheckingUpdates)
                        .help("检查最新模型定价")
                        .accessibilityLabel(isCheckingUpdates ? "正在检查模型定价" : "检查最新模型定价")
                        .onHover { isRefreshHovered = $0 }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .background(Color.white.opacity(0.08))

                    AdaptiveTable(minimumWidth: 720) {
                        VStack(spacing: 0) {
                            // 表头字段列
                            HStack(spacing: 10) {
                                Text("模型名称 / MODEL")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("服务商")
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

                            VStack(spacing: 0) {
                                ForEach(visiblePricings) { pricingItem in
                                    tableRow(for: pricingItem)
                                    if pricingItem.id != visiblePricings.last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.05))
                                    }
                                }
                                if visiblePricings.isEmpty {
                                    Text("没有该服务商的模型")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.tertiaryText)
                                        .frame(maxWidth: .infinity, minHeight: 72)
                                }
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
            .padding(.top, 36)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            preferences = store.load()
        }
    }

    // MARK: - 单行渲染
    private func tableRow(for item: ModelPricing) -> some View {
        let hasLocalOverride = hasLocalPriceOverride(item)
        let providerName = PricingProviderClassifier.providerName(for: item.modelName)
        let isHovered = hoveredModelId == item.id

        return HStack(spacing: 10) {
            // 1. 模型标识（等宽粗体白字）
            Text(item.modelName)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .help(item.modelName)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 2. 服务商列
            Text(providerName)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 78, alignment: .leading)

            // 3. 输入单价药丸单元格
            InlineEditablePillCell(
                value: item.inputPerMillion,
                symbol: item.baseCurrency.symbol,
                width: 76
            ) { newPrice in
                updatePrice(for: item, input: newPrice)
            }

            // 4. 缓存读取单价药丸单元格
            InlineEditablePillCell(
                value: item.cacheReadPerMillion,
                symbol: item.baseCurrency.symbol,
                isCache: true,
                width: 76
            ) { newPrice in
                updatePrice(for: item, cache: newPrice)
            }

            // 5. 输出单价药丸单元格
            InlineEditablePillCell(
                value: item.outputPerMillion,
                symbol: item.baseCurrency.symbol,
                width: 76
            ) { newPrice in
                updatePrice(for: item, output: newPrice)
            }

            // 6. 仅在本机价格不同于官方基准时显示恢复按钮
            ZStack {
                if hasLocalOverride {
                    Button {
                        restoreOfficialPricing(for: item)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("恢复为最新官方单价")
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
    private func hasLocalPriceOverride(_ item: ModelPricing) -> Bool {
        let key = DefaultModelPricings.normalizeModelName(item.modelName)
        guard let override = preferences.customOverrides[key],
              let official = officialPricing(for: key) else { return false }
        return !hasSameRates(override, official)
    }

    private func officialPricing(for modelName: String) -> ModelPricing? {
        let key = DefaultModelPricings.normalizeModelName(modelName)
        return preferences.syncedPricings[key]
            ?? DefaultModelPricings.presets.first(where: {
                DefaultModelPricings.normalizeModelName($0.modelName) == key
            })
    }

    private func hasSameRates(_ lhs: ModelPricing, _ rhs: ModelPricing) -> Bool {
        lhs.inputPerMillion == rhs.inputPerMillion &&
        lhs.cacheReadPerMillion == rhs.cacheReadPerMillion &&
        lhs.outputPerMillion == rhs.outputPerMillion &&
        lhs.baseCurrency == rhs.baseCurrency
    }

    @ViewBuilder
    private func providerFilterOption(_ provider: String) -> some View {
        Button {
            selectedProvider = provider
        } label: {
            HStack {
                Text(provider)
                Spacer()
                if selectedProvider == provider {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
        }
    }

    private func updatePrice(for item: ModelPricing, input: Double? = nil, cache: Double? = nil, output: Double? = nil) {
        let key = DefaultModelPricings.normalizeModelName(item.modelName)
        var current = preferences.customOverrides[key] ?? item
        if let input = input { current.inputPerMillion = max(0, input) }
        if let cache = cache { current.cacheReadPerMillion = max(0, cache) }
        if let output = output { current.outputPerMillion = max(0, output) }

        if let official = officialPricing(for: key), hasSameRates(current, official) {
            preferences.customOverrides.removeValue(forKey: key)
        } else {
            preferences.customOverrides[key] = current
        }
        save()
    }

    private func restoreOfficialPricing(for item: ModelPricing) {
        let key = DefaultModelPricings.normalizeModelName(item.modelName)
        preferences.customOverrides.removeValue(forKey: key)
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

        // 2. 最近一次成功同步的官方价格覆盖内置预设
        for p in preferences.syncedPricings.values {
            let canonical = DefaultModelPricings.normalizeModelName(p.modelName)
            var item = p
            item.modelName = canonical
            map[canonical] = item
        }

        // 3. 本机手动价格覆盖官方价格
        for p in preferences.customOverrides.values {
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
        updateErrorDetail = nil

        Task { @MainActor in
            do {
                let result = try await ModelPricingSyncService.shared.syncAndSave(store: store)
                self.preferences = store.load()
                self.isCheckingUpdates = false
                self.updateMessage = "已同步 \(result.totalCount) 款 · 更新 \(result.updatedCount) 项"
            } catch {
                self.isCheckingUpdates = false
                self.updateMessage = "同步失败 · 已保留本地费率"
                self.updateErrorDetail = error.localizedDescription
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
