import Foundation

/// 基于 UserDefaults 的模型计费偏好设置存储实现
struct UserDefaultsPricingSettingsStore: PricingSettingsStore {
    private enum Keys {
        static let pricingPreferences = "pricingPreferences_v1"
    }

    private let suiteName: String?

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    func load() -> PricingPreferences {
        guard let data = defaults.data(forKey: Keys.pricingPreferences),
              var preferences = try? JSONDecoder().decode(PricingPreferences.self, from: data) else {
            return PricingPreferences()
        }
        preferences.sanitizeCustomPricings()
        return preferences
    }

    func save(_ preferences: PricingPreferences) {
        var clean = preferences
        clean.sanitizeCustomPricings()
        if let data = try? JSONEncoder().encode(clean) {
            defaults.set(data, forKey: Keys.pricingPreferences)
        }
    }
}
