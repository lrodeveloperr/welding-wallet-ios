import SwiftUI

enum ShellConfiguration {
    static let appName = "Welding Gas Wallet"
    static let tint = Color(red: 23 / 255, green: 88 / 255, blue: 183 / 255)
    static let supportEmail = "lrodeveloperr@gmail.com"
    static let legal = LegalConfiguration(
        version: "1",
        privacyURL: URL(string: "https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/privacy/")!,
        termsURL: URL(string: "https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/terms/")!
    )
    static let onboarding: OnboardingProfile = .legalOnly

    /// Free users keep the complete wallet with a three-active-cylinder limit
    /// and a lower banner. A verified monthly subscription removes both.
    static let monetization = MonetizationConfiguration(
        mode: .adsWithSubscription,
        freeSuccessfulActions: 3,
        lifetimeProductID: "unused",
        subscriptionProductID: "com.gooduse.weldinggaswallet.pro.monthly"
    )
    static let advertising = AdvertisingConfiguration(
        bannerUnitID: Bundle.main.object(forInfoDictionaryKey: "WeldingAdBannerUnitID") as? String ?? ""
    )
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
        .init(id: "pt-BR", displayName: "Português (Brasil)"),
        .init(id: "fr", displayName: "Français"),
        .init(id: "ar", displayName: "العربية"),
        .init(id: "hi", displayName: "हिन्दी"),
        .init(id: "bn", displayName: "বাংলা"),
        .init(id: "ur", displayName: "اردو"),
        .init(id: "id", displayName: "Bahasa Indonesia"),
        .init(id: "vi", displayName: "Tiếng Việt"),
        .init(id: "ja", displayName: "日本語"),
        .init(id: "ru", displayName: "Русский"),
        .init(id: "zh-Hans", displayName: "简体中文"),
        .init(id: "zh-Hant", displayName: "繁體中文"),
        .init(id: "ms", displayName: "Bahasa Melayu"),
        .init(id: "ta", displayName: "தமிழ்"),
        .init(id: "te", displayName: "తెలుగు"),
        .init(id: "mr", displayName: "मराठी"),
        .init(id: "pa-Guru", displayName: "ਪੰਜਾਬੀ"),
        .init(id: "gu", displayName: "ગુજરાતી"),
        .init(id: "kn", displayName: "ಕನ್ನಡ"),
        .init(id: "ml", displayName: "മലയാളം"),
        .init(id: "th", displayName: "ไทย"),
        .init(id: "ko", displayName: "한국어"),
        .init(id: "fil", displayName: "Filipino"),
        .init(id: "fa", displayName: "فارسی"),
        .init(id: "sw", displayName: "Kiswahili"),
        .init(id: "ha", displayName: "Hausa"),
        .init(id: "am", displayName: "አማርኛ"),
        .init(id: "tr", displayName: "Türkçe"),
    ]
}

struct LegalConfiguration: Sendable { let version: String; let privacyURL: URL; let termsURL: URL }
enum OnboardingProfile: Equatable, Sendable { case legalOnly, singleScreen, guidedTour }
struct AdvertisingConfiguration: Sendable { let bannerUnitID: String }
struct BackupConfiguration: Sendable { let enabled: Bool }

struct MonetizationConfiguration: Sendable {
    let mode: MonetizationMode
    let freeSuccessfulActions: Int
    let lifetimeProductID: String
    let subscriptionProductID: String
    var productIDs: Set<String> {
        switch mode {
        case .adsWithRemovePurchase, .oneTimeUnlock, .usageCapWithOneTimeUnlock: [lifetimeProductID]
        case .adsWithSubscription, .subscription, .usageCapWithSubscription: [subscriptionProductID]
        case .free, .ads: []
        }
    }
    var includesAdvertising: Bool { mode == .ads || mode == .adsWithRemovePurchase || mode == .adsWithSubscription }
    var includesPurchase: Bool { !productIDs.isEmpty }
}

struct ShellDestination: Hashable, Identifiable, Sendable { let id: String; let titleKey: String; let symbol: String }
struct AppLanguage: Identifiable, Hashable, Sendable { let id: String; let displayName: String }

enum MonetizationMode: String, CaseIterable, Identifiable, Sendable {
    case free, ads, adsWithRemovePurchase, adsWithSubscription
    case oneTimeUnlock, subscription, usageCapWithOneTimeUnlock, usageCapWithSubscription
    var id: Self { self }
    var title: String {
        switch self {
        case .free: "Free"
        case .ads: "Ads"
        case .adsWithRemovePurchase: "Ads + remove purchase"
        case .adsWithSubscription: "Ads + subscription"
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
