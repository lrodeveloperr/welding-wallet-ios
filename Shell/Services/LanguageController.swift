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
        if let stored = defaults.string(forKey: key), ShellConfiguration.supportedLanguages.contains(where: { $0.id == stored }) {
            selection = stored
        } else {
            selection = Self.closestSupported(to: preferredLanguages.first ?? "en")
        }
    }

    var locale: Locale { Locale(identifier: selection) }

    static func closestSupported(to candidate: String) -> String {
        let normalized = candidate.replacingOccurrences(of: "_", with: "-").lowercased()
        if let exact = ShellConfiguration.supportedLanguages.first(where: {
            normalized == $0.id.lowercased() || normalized.hasPrefix($0.id.lowercased() + "-")
        }) { return exact.id }
        if normalized.hasPrefix("es"), ShellConfiguration.supportedLanguages.contains(where: { $0.id == "es-419" }) { return "es-419" }
        return "en"
    }
}
