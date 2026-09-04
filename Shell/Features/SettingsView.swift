import StoreKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let model: ShellModel
    let wallet: WalletStore
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageController.self) private var language
    @State private var showDelete = false
    @State private var showPaywall = false
    @State private var deletePhrase = ""
    @State private var legalDocument: LegalDocument?
    @State private var showingManageSubscriptions = false

    var body: some View {
        List {
            if shouldShowUpgrade {
                Section {
                    Button { showPaywall = true } label: {
                        SettingsLabel("Upgrade", verbatimSubtitle: upgradeSubtitle, symbol: "sparkles")
                    }
                    .accessibilityIdentifier("shell.settings.upgrade")
                }
            }
            if let subscriptionPresentation {
                Section {
                    SettingsLabel(
                        "subscription.status",
                        verbatimSubtitle: subscriptionStatus,
                        symbol: subscriptionPresentation.symbol
                    )
                    if subscriptionPresentation.showsManagement {
                        Button { showingManageSubscriptions = true } label: {
                            SettingsLabel("subscription.manage", subtitle: "subscription.manage.subtitle", symbol: "person.crop.circle.badge.checkmark")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("shell.settings.subscription.manage")
                    }
                }
            }
            Section {
                NavigationLink { LanguageView() } label: { SettingsLabel("Language", subtitle: "Choose the app language", symbol: "globe") }
                NavigationLink { CurrencyView(wallet: wallet) } label: { SettingsLabel("Currency", verbatimSubtitle: "\(wallet.currencySign(for: wallet.defaultCurrency)) · \(AppLocalization.string(wallet.currencyOverride == nil ? "Automatic" : "Selected", locale: locale))", symbol: "dollarsign.circle") }
                NavigationLink { BackupView(wallet: wallet, isEntitled: { model.access.isEntitled }) } label: { SettingsLabel("Backup", subtitle: "Optional native file backup", symbol: "externaldrive.badge.icloud") }
                NavigationLink { HelpView() } label: { SettingsLabel("Help", subtitle: "Simple numbered guide", symbol: "questionmark.circle") }
            }
            Section {
                legalButton(.privacy, title: "Privacy policy", symbol: "hand.raised.shield")
                legalButton(.terms, title: "Terms of use", symbol: "doc.text")
                legalButton(.support, title: "Support", symbol: "questionmark.bubble")
                legalButton(.deletion, title: "Data deletion", symbol: "trash.slash")
                legalButton(.safety, title: "Safety notice", symbol: "exclamationmark.triangle")
            }
            Section { Button(role: .destructive) { showDelete = true } label: { SettingsLabel("Delete all data", subtitle: "Erase this wallet from this device", symbol: "trash") } }
            Section { Text("Welding Gas Wallet · Cylinder records stay on this device").font(.footnote).foregroundStyle(.secondary) }
        }
        .appNavigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(AppLocalization.string("Done", locale: locale)) { dismiss() }
            }
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView(showsDoneButton: true) }
                .environment(model)
        }
        .sheet(item: $legalDocument) { document in
            LegalView(document: document)
                .ignoresSafeArea()
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .alert("Delete all data?", isPresented: $showDelete) {
            TextField("delete.typeWord", text: $deletePhrase).textInputAutocapitalization(.characters)
            Button("Delete all data", role: .destructive) { if deletionPhraseMatches { wallet.deleteAllData(); dismiss() }; deletePhrase = "" }.disabled(!deletionPhraseMatches)
            Button("Cancel", role: .cancel) { deletePhrase = "" }
        } message: { Text("This removes cylinders, suppliers, costs, activity, reminders and preferences. Purchases and separately saved backup files are not deleted.") }
    }

    private var deletionPhraseMatches: Bool {
        deletePhrase.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(AppLocalization.string("delete.confirmationWord", locale: locale)) == .orderedSame
    }

    private var locale: Locale { language.locale }

    private var shouldShowUpgrade: Bool {
        guard !model.access.isEntitled else { return false }
        switch model.access.purchases.subscriptionCondition {
        case .checking, .billingRetry, .subscribed, .gracePeriod, .offlineCached:
            return false
        case .notApplicable, .expired, .revoked:
            return true
        }
    }

    private var subscriptionPresentation: SubscriptionSettingsPresentation? {
        guard ShellConfiguration.monetization.includesSubscription else { return nil }
        return SubscriptionSettingsPresentation.resolve(model.access.purchases.subscriptionCondition)
    }

    private var upgradeSubtitle: String {
        guard let product = model.access.purchases.primaryProduct else {
            return AppLocalization.string("settings.upgrade.unlimited", locale: locale)
        }
        guard let subscription = product.subscription else {
            return AppLocalization.string("settings.upgrade.price %@", locale: locale, product.displayPrice)
        }
        return AppLocalization.string(
            "settings.upgrade.price.period %@ %@",
            locale: locale,
            product.displayPrice,
            subscriptionPeriod(subscription.subscriptionPeriod)
        )
    }

    private func subscriptionPeriod(_ period: Product.SubscriptionPeriod) -> String {
        let unit: NSCalendar.Unit
        switch period.unit {
        case .day: unit = .day
        case .week: unit = .weekOfMonth
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: return AppLocalization.string("paywall.period.unknown", locale: locale)
        }
        return AppLocalization.duration(period.value, unit: unit, locale: locale)
            ?? AppLocalization.string("paywall.period.unknown", locale: locale)
    }

    private var subscriptionStatus: String {
        switch model.access.purchases.subscriptionCondition {
        case .notApplicable, .expired, .revoked:
            return AppLocalization.string("subscription.inactive", locale: locale)
        case .checking:
            return AppLocalization.string("access.checking", locale: locale)
        case let .subscribed(willAutoRenew, expiration):
            return AppLocalization.string(willAutoRenew ? "subscription.renews %@" : "subscription.ends %@", locale: locale, subscriptionDate(expiration))
        case let .gracePeriod(expiration):
            return AppLocalization.string("subscription.grace %@", locale: locale, subscriptionDate(expiration))
        case .billingRetry:
            return AppLocalization.string("subscription.billingRetry", locale: locale)
        case let .offlineCached(expiration):
            return AppLocalization.string("subscription.offline %@", locale: locale, subscriptionDate(expiration))
        }
    }

    private func subscriptionDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).day().month(.abbreviated).year())
    }

    private func legalButton(_ document: LegalDocument, title: String, symbol: String) -> some View {
        Button { legalDocument = document } label: {
            SettingsLabel(LocalizedStringKey(title), subtitle: "legal.documentLanguage", symbol: symbol)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("shell.settings.legal.\(document.rawValue)")
    }
}

struct SubscriptionSettingsPresentation: Equatable {
    let showsManagement: Bool
    let symbol: String

    static func resolve(_ condition: SubscriptionCondition) -> Self? {
        switch condition {
        case .notApplicable, .expired, .revoked:
            return nil
        case .checking:
            return Self(showsManagement: false, symbol: "hourglass")
        case .subscribed:
            return Self(showsManagement: true, symbol: "checkmark.seal.fill")
        case .gracePeriod, .billingRetry:
            return Self(showsManagement: true, symbol: "exclamationmark.triangle.fill")
        case .offlineCached:
            return Self(showsManagement: true, symbol: "checkmark.seal")
        }
    }
}

private struct SettingsLabel: View {
    let title: LocalizedStringKey; let subtitle: LocalizedStringKey?; let verbatimSubtitle: String?; let symbol: String
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, verbatimSubtitle: String? = nil, symbol: String) { self.title = title; self.subtitle = subtitle; self.verbatimSubtitle = verbatimSubtitle; self.symbol = symbol }
    var body: some View { Label { VStack(alignment: .leading, spacing: 2) { Text(title).foregroundStyle(Color.primary); if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Color.secondary) }; if let verbatimSubtitle { Text(verbatimSubtitle).font(.caption).foregroundStyle(Color.secondary) } } } icon: { Image(systemName: symbol).foregroundStyle(.tint).frame(width: 28) }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }
}

private struct LanguageView: View {
    @Environment(LanguageController.self) private var language
    var body: some View {
        @Bindable var language = language
        List(ShellConfiguration.supportedLanguages) { option in Button { language.selection = option.id } label: { HStack { Image(systemName: "globe").foregroundStyle(.tint); Text(option.displayName).foregroundStyle(.primary); Spacer(); if language.selection == option.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) } }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle()) }.accessibilityAddTraits(language.selection == option.id ? .isSelected : []) }
            .appNavigationTitle("Language").navigationBarTitleDisplayMode(.inline)
    }
}

private struct CurrencyView: View {
    @Bindable var wallet: WalletStore
    @Environment(LanguageController.self) private var language
    @State private var query = ""
    private var codes: [String] {
        WalletStore.selectableCurrencyCodes.filter {
            query.isEmpty
                || $0.localizedCaseInsensitiveContains(query)
                || (locale.localizedString(forCurrencyCode: $0) ?? "").localizedCaseInsensitiveContains(query)
        }
    }
    var body: some View {
        List {
            Section { Button { wallet.setCurrency(nil) } label: { HStack { Text(wallet.currencySign(for: wallet.automaticCurrency)).frame(width: 34); VStack(alignment: .leading) { Text("Automatic"); Text("Device region").font(.caption).foregroundStyle(.secondary) }; Spacer(); if wallet.currencyOverride == nil { Image(systemName: "checkmark.circle.fill") } } } }
            Section { ForEach(codes, id: \.self) { code in Button { wallet.setCurrency(code) } label: { HStack { Text(wallet.currencySign(for: code)).frame(width: 34); Text(locale.localizedString(forCurrencyCode: code) ?? code).foregroundStyle(.primary); Spacer(); if wallet.currencyOverride == code { Image(systemName: "checkmark.circle.fill") } } } } }
        }
        .searchable(text: $query, prompt: Text(verbatim: AppLocalization.string("Search currencies", locale: locale)))
        .appNavigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var locale: Locale { language.locale }
}

private struct BackupView: View {
    @Bindable var wallet: WalletStore
    let isEntitled: () -> Bool
    @Environment(\.locale) private var locale
    @State private var exporting = false; @State private var importing = false; @State private var document = WalletBackupDocument(); @State private var message = ""
    var body: some View {
        List {
            Section { Label("Keep a file copy", systemImage: "externaldrive.badge.icloud").font(.headline); Text("Use the native file picker to save to iCloud Drive, On My iPhone, or another Files location.").foregroundStyle(.secondary) }
            Section { Button("Save backup file", systemImage: "square.and.arrow.up") { do { document = WalletBackupDocument(data: try wallet.exportData()); exporting = true } catch { message = error.localizedDescription } }; Button("Restore backup file", systemImage: "square.and.arrow.down") { importing = true } }
            if !message.isEmpty { Section { Text(message) } }
            Section { Label("Backup files never include purchase entitlement.", systemImage: "lock") }
        }
        .appNavigationTitle("Backup").navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "welding-wallet-backup-\(Self.dateStamp)") { result in message = AppLocalization.string(result.isSuccess ? "backup.fileCreated" : "backup.notSaved", locale: locale) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in do { let url = try result.get(); guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }; defer { url.stopAccessingSecurityScopedResource() }; let entitled = isEntitled(); try wallet.restore(from: Data(contentsOf: url), isEntitled: entitled, locale: locale); message = AppLocalization.string(wallet.requiresFreeCylinderSelection(isEntitled: entitled) ? "backup.restored.selectionRequired" : "backup.restored", locale: locale) } catch let error as WalletError { message = backupErrorMessage(error) } catch { message = error.localizedDescription } }
    }
    private func backupErrorMessage(_ error: WalletError) -> String {
        switch error {
        case .backupTooLarge: AppLocalization.string("backup.error.tooLarge", locale: locale)
        case .unsupportedBackup: AppLocalization.string("backup.error.unsupported", locale: locale)
        case .invalidBackup: AppLocalization.string("backup.error.invalid", locale: locale)
        case .activeCylinderLimit(let limit): AppLocalization.string("backup.activeLimit", locale: locale, limit)
        case .persistenceFailure, .corruptStoreRecovered: error.localizedDescription
        }
    }
    private static var dateStamp: String { String(ISO8601DateFormatter().string(from: .now).prefix(10)) }
}

private struct HelpView: View {
    let steps: [LocalizedStringKey] = ["Add a cylinder with only its gas and capacity.", "Copy an existing cylinder when the details are similar.", "Tap a status whenever it changes.", "Record a refill or exchange; today and your currency are already selected.", "Return or archive a cylinder when it leaves your active inventory.", "Create a backup file before moving to a new phone."]
    var body: some View { List { ForEach(Array(steps.enumerated()), id: \.offset) { index, step in HStack(alignment: .top, spacing: 14) { Text("\(index + 1)").font(.headline).foregroundStyle(.tint).frame(width: 32, height: 32).background(Color.blue.opacity(0.08), in: Circle()); Text(step) } }; Section { Text("If you make a mistake, edit the cylinder or use Delete cylinder and Undo.").foregroundStyle(.secondary) } }.appNavigationTitle("Help").navigationBarTitleDisplayMode(.inline) }
}

private extension Result { var isSuccess: Bool { if case .success = self { true } else { false } } }
