import SwiftUI
import Observation

enum SupportedLocaleResolver {
    private static let aliases: [String: String] = [
        "es": "es-419",
        "zh": "zh-Hans",
    ]

    static func closestSupported(to candidate: String) -> String {
        let normalized = candidate.replacingOccurrences(of: "_", with: "-").lowercased()
        let supported = ShellConfiguration.supportedLanguages

        if let exact = supported.first(where: { normalized == $0.id.lowercased() }) {
            return exact.id
        }

        let primaryLanguage = normalized.split(separator: "-").first.map(String.init) ?? normalized
        if let alias = aliases[primaryLanguage], supported.contains(where: { $0.id == alias }) {
            return alias
        }
        if let primary = supported.first(where: { $0.id.lowercased() == primaryLanguage }) {
            return primary.id
        }
        return "en"
    }

    static func isRightToLeft(_ identifier: String) -> Bool {
        ["ar", "he", "ur"].contains(identifier.split(separator: "-").first.map(String.init)?.lowercased() ?? identifier.lowercased())
    }
}

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
    var layoutDirection: LayoutDirection { SupportedLocaleResolver.isRightToLeft(selection) ? .rightToLeft : .leftToRight }

    static func closestSupported(to candidate: String) -> String {
        SupportedLocaleResolver.closestSupported(to: candidate)
    }
}
