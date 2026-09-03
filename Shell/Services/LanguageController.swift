import Foundation
import Observation

@MainActor
@Observable
final class LanguageController {
    private let defaults: UserDefaults
    private let key = "wallet.language"
    var selection: String { didSet { defaults.set(selection, forKey: key) } }

    init(defaults: UserDefaults = .standard, preferredLanguages: [String] = Locale.preferredLanguages) {
        self.defaults = defaults
        selection = defaults.string(forKey: key) ?? Self.closestSupported(to: preferredLanguages.first ?? "en")
    }

    var locale: Locale { Locale(identifier: selection) }

    static func closestSupported(to candidate: String) -> String {
        let normalized = candidate.replacingOccurrences(of: "_", with: "-").lowercased()
        if normalized.hasPrefix("zh-tw") || normalized.hasPrefix("zh-hk") || normalized.hasPrefix("zh-mo") || normalized.contains("hant") { return "zh-Hant" }
        if normalized.hasPrefix("zh") { return "zh-Hans" }
        if normalized.hasPrefix("es") { return "es-419" }
        if normalized.hasPrefix("pt") { return "pt-BR" }
        if normalized.hasPrefix("pa") { return "pa-Guru" }
        if normalized.hasPrefix("tl") { return "fil" }
        return ShellConfiguration.supportedLanguages.first {
            normalized == $0.id.lowercased() || normalized.hasPrefix($0.id.lowercased() + "-")
        }?.id ?? "en"
    }
}
