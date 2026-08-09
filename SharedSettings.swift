import Foundation

enum SharedSettings {
    static let appGroupIdentifier = "group.com.tobekirilled.udmurtkeyboard"

    static let suggestionsEnabledKey = "settings.suggestionsEnabled"
    static let autocorrectionEnabledKey = "settings.autocorrectionEnabled"
    static let personalDictionaryEnabledKey = "settings.personalDictionaryEnabled"
    static let resetPersonalDictionaryRequestedKey = "settings.resetPersonalDictionaryRequested"

    static let userWordWeightsKey = "userWordWeights.v1"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func registerDefaults() {
        defaults.register(defaults: [
            suggestionsEnabledKey: true,
            autocorrectionEnabledKey: true,
            personalDictionaryEnabledKey: true,
            resetPersonalDictionaryRequestedKey: false
        ])
    }

    static func bool(_ key: String, defaultValue: Bool = true) -> Bool {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }

        return defaults.bool(forKey: key)
    }
}
