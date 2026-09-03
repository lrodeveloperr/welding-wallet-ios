import Foundation

enum AppLocalization {
    private static let presetGases: Set<String> = ["Argon", "C25 Mix", "Oxygen", "Acetylene", "Nitrogen", "CO₂", "Helium"]

    static func string(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        let language = identifier.lowercased().hasPrefix("es") ? "es-419" : "en"
        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        let bundle = path.flatMap { Bundle(path: $0) } ?? .main
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, locale: locale, arguments: arguments)
    }

    static func decimal(from text: String, locale: Locale) -> Decimal? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        if let value = formatter.number(from: text) as? NSDecimalNumber { return value.decimalValue }
        return Decimal(string: text.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }

    static func double(from text: String, locale: Locale) -> Double? {
        decimal(from: text, locale: locale).map { NSDecimalNumber(decimal: $0).doubleValue }
    }

    static func gas(_ canonicalValue: String, locale: Locale) -> String {
        presetGases.contains(canonicalValue) ? string(canonicalValue, locale: locale) : canonicalValue
    }

    static func supplier(_ storedValue: String, locale: Locale) -> String {
        storedValue == "Not set" ? string("common.notSet", locale: locale) : storedValue
    }

    static func number(_ value: Decimal, locale: Locale, minimumFractionDigits: Int = 0, maximumFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? NSDecimalNumber(decimal: value).stringValue
    }

    static func number(_ value: Double, locale: Locale, maximumFractionDigits: Int = 1) -> String {
        number(Decimal(value), locale: locale, maximumFractionDigits: maximumFractionDigits)
    }
}
