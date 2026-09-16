import Foundation

/// Resolve the ordered system language preferences, including regional variants.
/// Explicit bundle lookup also gives runtime status/error strings the same fallback as UI.
enum L10n {
    static let supported = ["en", "zh-Hans", "ja", "fr", "es"]
    static let language = resolve(Locale.preferredLanguages)
    static let locale = Locale(identifier: language)

    static func resolve(_ preferences: [String]) -> String {
        for preference in preferences {
            switch preference.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").first {
            case "en": return "en"
            case "zh": return "zh-Hans"
            case "ja": return "ja"
            case "fr": return "fr"
            case "es": return "es"
            default: continue
            }
        }
        return "en"
    }

    static func localized(_ key: String, language: String = language, bundle: Bundle = .main) -> String {
        func lookup(_ language: String) -> String? {
            guard let path = bundle.path(forResource: language, ofType: "lproj"),
                  let resource = Bundle(path: path) else { return nil }
            let missing = "__FUSEBAR_MISSING_LOCALIZATION__"
            let value = resource.localizedString(forKey: key, value: missing, table: "Localizable")
            return value == missing ? nil : value
        }
        return lookup(language) ?? lookup("en") ?? key
    }
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    let value = L10n.localized(key)
    return arguments.isEmpty ? value : String(format: value, locale: L10n.locale, arguments: arguments)
}
