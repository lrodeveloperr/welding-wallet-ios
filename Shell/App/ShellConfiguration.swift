import SwiftUI

enum ShellConfiguration {
    static let appName = "Welding Gas Wallet"
    static let tint = Color(red: 23 / 255, green: 88 / 255, blue: 183 / 255)
    static let supportEmail = "lrodeveloperr@gmail.com"
    static let legal = LegalConfiguration(
        version: "1",
        privacyURL: URL(string: "https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/privacy/")!,
        termsURL: URL(string: "https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/terms/")!,
        supportURL: URL(string: "https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/support/")!,
        deletionURL: URL(string: "https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/deletion/")!,
        safetyURL: URL(string: "https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/disclaimer/")!
    )
    static let onboarding: OnboardingProfile = .legalOnly

    /// Free users keep the complete wallet with a three-active-cylinder limit.
    /// A verified monthly subscription unlocks unlimited active cylinders.
    /// App Store Connect owns the US$1.99 monthly price configuration;
    /// customer-facing UI must use StoreKit's storefront-localized price.
#if SCREENSHOT_BUILD
    static let monetization = MonetizationConfiguration(
        mode: .free,
        freeSuccessfulActions: .max,
        lifetimeProductID: "unused",
        subscriptionProductID: "unused"
    )
#else
    static let monetization = MonetizationConfiguration(
        mode: .freemiumWithSubscription,
        freeSuccessfulActions: .max,
        lifetimeProductID: "unused",
        subscriptionProductID: "com.gooduse.weldinggaswallet.pro.monthly"
    )
#endif
    static let backup = BackupConfiguration(enabled: true)
    static let migrations: [ShellMigration] = []
    static let destinations: [ShellDestination] = [
        .init(id: "cylinders", titleKey: "destination.cylinders", symbol: "cylinder"),
        .init(id: "activity", titleKey: "destination.activity", symbol: "clock"),
        .init(id: "suppliers", titleKey: "destination.suppliers", symbol: "person.2"),
    ]

    /// The first launch resolves the closest supported device language. Settings
    /// intentionally lists only explicit choices—there is no “Follow system” row.
    static let supportedLanguages: [AppLanguage] = [
        .init(id: "en", displayName: "English"),
        .init(id: "es-419", displayName: "Español (Latinoamérica)"),
    ]
}

struct LegalConfiguration: Sendable {
    let version: String
    let privacyURL: URL
    let termsURL: URL
    let supportURL: URL
    let deletionURL: URL
    let safetyURL: URL
}
enum OnboardingProfile: Equatable, Sendable { case legalOnly, singleScreen, guidedTour }
struct BackupConfiguration: Sendable { let enabled: Bool }

struct MonetizationConfiguration: Sendable {
    let mode: MonetizationMode
    let freeSuccessfulActions: Int
    let lifetimeProductID: String
    let subscriptionProductID: String
    var productIDs: Set<String> {
        switch mode {
        case .oneTimeUnlock, .usageCapWithOneTimeUnlock: [lifetimeProductID]
        case .freemiumWithSubscription, .subscription, .usageCapWithSubscription: [subscriptionProductID]
        case .free: []
        }
    }
    var includesPurchase: Bool { !productIDs.isEmpty }
}

struct ShellDestination: Hashable, Identifiable, Sendable { let id: String; let titleKey: String; let symbol: String }
struct AppLanguage: Identifiable, Hashable, Sendable { let id: String; let displayName: String }

enum MonetizationMode: String, CaseIterable, Identifiable, Sendable {
    case free, freemiumWithSubscription
    case oneTimeUnlock, subscription, usageCapWithOneTimeUnlock, usageCapWithSubscription
    var id: Self { self }
    var title: String {
        switch self {
        case .free: "Free"
        case .freemiumWithSubscription: "Free feature limit + subscription"
        case .oneTimeUnlock: "One-time unlock"
        case .subscription: "Subscription"
        case .usageCapWithOneTimeUnlock: "Usage cap + one-time unlock"
        case .usageCapWithSubscription: "Usage cap + subscription"
        }
    }
}

enum SampleContentState: String, CaseIterable, Identifiable, Sendable {
    case populated, empty, loading, error
    var id: Self { self }
    var title: String { rawValue.capitalized }
}
