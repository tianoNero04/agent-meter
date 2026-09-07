import Foundation

/// 模型计费与币种设置持久化端口
protocol PricingSettingsStore: Sendable {
    /// 加载当前持久化的计费偏好
    func load() -> PricingPreferences
    /// 保存计费偏好
    func save(_ preferences: PricingPreferences)
}
