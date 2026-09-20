import Foundation

/// 顶部 Provider 导航的应用界面状态，由 `ProviderPreferences` 与本地检测环境映射而来。
struct ProviderNavigationState: Equatable {
    /// 用户在偏好设置中启用的 Provider 集合
    private(set) var enabledProviders: Set<Provider>
    /// 本地环境检测扫描到的已安装 Provider 集合（默认包含所有以保持单元测试向后兼容）
    private(set) var detectedProviders: Set<Provider>
    /// 当前在菜单栏浮窗中选中的 Provider
    private(set) var selectedProvider: Provider?

    /// 浮窗菜单栏动态显示的提供商列表：严格为「已在本地检测到」且「用户处于开启状态」的提供商
    var visibleProviders: [Provider] {
        Provider.allCases.filter { provider in
            detectedProviders.contains(provider) && enabledProviders.contains(provider)
        }
    }

    init(
        enabledProviders: Set<Provider> = Set(Provider.coreProviders),
        detectedProviders: Set<Provider> = Set(Provider.coreProviders),
        selectedProvider: Provider? = .codex
    ) {
        self.enabledProviders = enabledProviders
        self.detectedProviders = detectedProviders
        let visible = Provider.allCases.filter { detectedProviders.contains($0) && enabledProviders.contains($0) }
        self.selectedProvider = selectedProvider.flatMap { visible.contains($0) ? $0 : visible.first }
    }

    init(preferences: ProviderPreferences, detectedProviders: Set<Provider> = Set(Provider.coreProviders)) {
        self.init(
            enabledProviders: preferences.enabledProviders,
            detectedProviders: detectedProviders,
            selectedProvider: preferences.selectedProvider ?? .codex
        )
    }

    var preferences: ProviderPreferences {
        ProviderPreferences(enabledProviders: enabledProviders, selectedProvider: selectedProvider)
    }

    /// 更新本地环境检测结果，并自动平滑校正当前选中的 Provider
    mutating func updateDetectedProviders(_ detected: Set<Provider>) {
        self.detectedProviders = detected
        if let current = selectedProvider, !visibleProviders.contains(current) {
            selectedProvider = visibleProviders.first
        } else if selectedProvider == nil {
            selectedProvider = visibleProviders.first
        }
    }

    /// 设置某个 Provider 的开启/关闭开关状态
    mutating func setProviderEnabled(_ provider: Provider, _ enabled: Bool) {
        if enabled {
            enabledProviders.insert(provider)
            if selectedProvider == nil { selectedProvider = provider }
        } else {
            enabledProviders.remove(provider)
            if selectedProvider == provider { selectedProvider = visibleProviders.first }
        }
    }

    /// 切换选中指定 Provider（必须处于开启且检测到的状态）
    mutating func selectProvider(_ provider: Provider) {
        guard visibleProviders.contains(provider) else { return }
        selectedProvider = provider
    }

    /// 查询某 Provider 是否在设置中处于开启状态
    func isEnabled(_ provider: Provider) -> Bool {
        enabledProviders.contains(provider)
    }

    /// 查询某 Provider 是否已在本地检测到安装
    func isDetected(_ provider: Provider) -> Bool {
        detectedProviders.contains(provider)
    }
}
