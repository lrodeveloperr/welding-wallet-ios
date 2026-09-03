import Foundation

enum AppLocalization {
    private static let presetGases: Set<String> = ["Argon", "C25 Mix", "Oxygen", "Acetylene", "Nitrogen", "CO₂", "Helium"]

    static func string(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        let language = SupportedLocaleResolver.closestSupported(to: locale.identifier)
        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        let bundle = path.flatMap { Bundle(path: $0) } ?? .main
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, locale: locale, arguments: arguments)
    }

    static var selectedLocale: Locale {
        Locale(identifier: UserDefaults.standard.string(forKey: "wallet.language") ?? Locale.preferredLanguages.first ?? "en")
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

    static func labeledCount(_ labelKey: String, count: Int, locale: Locale) -> String {
        "\(string(labelKey, locale: locale)): \(number(Decimal(count), locale: locale))"
    }

    static func duration(_ value: Int, unit: NSCalendar.Unit, locale: Locale) -> String? {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar
        formatter.allowedUnits = unit
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        var components = DateComponents()
        switch unit {
        case .day: components.day = value
        case .weekOfMonth: components.weekOfMonth = value
        case .month: components.month = value
        case .year: components.year = value
        default: return nil
        }
        return formatter.string(from: components)
    }
}
