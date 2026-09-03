import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let model: ShellModel
    let wallet: WalletStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var showDelete = false
    @State private var showPaywall = false
    @State private var deletePhrase = ""
    @State private var legalDocument: LegalDocument?

    var body: some View {
        List {
            if !model.access.isEntitled {
                Section {
                    Button { showPaywall = true } label: {
                        SettingsLabel("Upgrade", verbatimSubtitle: upgradeSubtitle, symbol: "sparkles")
                    }
                    .accessibilityIdentifier("shell.settings.upgrade")
                }
            }
            Section {
                NavigationLink { LanguageView() } label: { SettingsLabel("Language", subtitle: "Choose the app language", symbol: "globe") }
                NavigationLink { CurrencyView(wallet: wallet) } label: { SettingsLabel("Currency", verbatimSubtitle: "\(wallet.currencySign(for: wallet.defaultCurrency)) · \(AppLocalization.string(wallet.currencyOverride == nil ? "Automatic" : "Selected", locale: locale))", symbol: "dollarsign.circle") }
                NavigationLink { BackupView(wallet: wallet, activeCylinderLimit: model.access.isEntitled ? nil : 3) } label: { SettingsLabel("Backup", subtitle: "Optional native file backup", symbol: "externaldrive.badge.icloud") }
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
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView(showsDoneButton: true) }
                .environment(model)
        }
        .sheet(item: $legalDocument) { document in
            LegalView(document: document)
                .ignoresSafeArea()
        }
        .alert("Delete all data?", isPresented: $showDelete) {
            TextField("delete.typeWord", text: $deletePhrase).textInputAutocapitalization(.characters)
            Button("Delete all data", role: .destructive) { if deletionPhraseMatches { wallet.deleteAllData(); dismiss() }; deletePhrase = "" }.disabled(!deletionPhraseMatches)
            Button("Cancel", role: .cancel) { deletePhrase = "" }
        } message: { Text("This removes cylinders, suppliers, costs, activity, reminders and preferences. Purchases and separately saved backup files are not deleted.") }
    }

    private var deletionPhraseMatches: Bool {
        deletePhrase.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(AppLocalization.string("delete.confirmationWord", locale: locale)) == .orderedSame
    }

    private var upgradeSubtitle: String {
        guard let product = model.access.purchases.primaryProduct else {
            return AppLocalization.string("settings.upgrade.unlimited", locale: locale)
        }
        return AppLocalization.string("settings.upgrade.price %@", locale: locale, product.displayPrice)
    }

    private func legalButton(_ document: LegalDocument, title: String, symbol: String) -> some View {
        Button { legalDocument = document } label: {
            SettingsLabel(LocalizedStringKey(title), subtitle: "legal.documentLanguage", symbol: symbol)
        }
        .accessibilityIdentifier("shell.settings.legal.\(document.rawValue)")
    }
}

private struct SettingsLabel: View {
    let title: LocalizedStringKey; let subtitle: LocalizedStringKey?; let verbatimSubtitle: String?; let symbol: String
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, verbatimSubtitle: String? = nil, symbol: String) { self.title = title; self.subtitle = subtitle; self.verbatimSubtitle = verbatimSubtitle; self.symbol = symbol }
    var body: some View { Label { VStack(alignment: .leading, spacing: 2) { Text(title).foregroundStyle(.primary); if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }; if let verbatimSubtitle { Text(verbatimSubtitle).font(.caption).foregroundStyle(.secondary) } } } icon: { Image(systemName: symbol).foregroundStyle(.tint).frame(width: 28) } }
}

private struct LanguageView: View {
    @Environment(LanguageController.self) private var language
    var body: some View {
        @Bindable var language = language
        List(ShellConfiguration.supportedLanguages) { option in Button { language.selection = option.id } label: { HStack { Image(systemName: "globe").foregroundStyle(.tint); Text(option.displayName).foregroundStyle(.primary); Spacer(); if language.selection == option.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) } } }.accessibilityAddTraits(language.selection == option.id ? .isSelected : []) }
            .navigationTitle("Language").navigationBarTitleDisplayMode(.inline)
    }
}

private struct CurrencyView: View {
    @Bindable var wallet: WalletStore
    @Environment(\.locale) private var locale
    @State private var query = ""
    private var codes: [String] { Locale.Currency.isoCurrencies.map(\.identifier).filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) || (locale.localizedString(forCurrencyCode: $0) ?? "").localizedCaseInsensitiveContains(query) }.sorted() }
    var body: some View {
        List {
            Section { Button { wallet.setCurrency(nil) } label: { HStack { Text(wallet.currencySign(for: wallet.automaticCurrency)).frame(width: 34); VStack(alignment: .leading) { Text("Automatic"); Text("Device region").font(.caption).foregroundStyle(.secondary) }; Spacer(); if wallet.currencyOverride == nil { Image(systemName: "checkmark.circle.fill") } } } }
            Section { ForEach(codes, id: \.self) { code in Button { wallet.setCurrency(code) } label: { HStack { Text(wallet.currencySign(for: code)).frame(width: 34); Text(locale.localizedString(forCurrencyCode: code) ?? code).foregroundStyle(.primary); Spacer(); if wallet.currencyOverride == code { Image(systemName: "checkmark.circle.fill") } } } } }
        }.searchable(text: $query, prompt: "Search currencies").navigationTitle("Currency").navigationBarTitleDisplayMode(.inline)
    }
}

private struct BackupView: View {
    @Bindable var wallet: WalletStore
    let activeCylinderLimit: Int?
    @Environment(\.locale) private var locale
    @State private var exporting = false; @State private var importing = false; @State private var document = WalletBackupDocument(); @State private var message = ""
    var body: some View {
        List {
            Section { Label("Keep a file copy", systemImage: "externaldrive.badge.icloud").font(.headline); Text("Use the native file picker to save to iCloud Drive, On My iPhone, or another Files location.").foregroundStyle(.secondary) }
            Section { Button("Save backup file", systemImage: "square.and.arrow.up") { do { document = WalletBackupDocument(data: try wallet.exportData()); exporting = true } catch { message = error.localizedDescription } }; Button("Restore backup file", systemImage: "square.and.arrow.down") { importing = true } }
            if !message.isEmpty { Section { Text(message) } }
            Section { Label("Backup files never include purchase entitlement.", systemImage: "lock") }
        }
        .navigationTitle("Backup").navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "welding-wallet-backup-\(Self.dateStamp)") { result in message = AppLocalization.string(result.isSuccess ? "backup.fileCreated" : "backup.notSaved", locale: locale) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in do { let url = try result.get(); guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }; defer { url.stopAccessingSecurityScopedResource() }; try wallet.restore(from: Data(contentsOf: url), activeCylinderLimit: activeCylinderLimit, locale: locale); message = AppLocalization.string("backup.restored", locale: locale) } catch let error as WalletError { message = backupErrorMessage(error) } catch { message = error.localizedDescription } }
    }
    private func backupErrorMessage(_ error: WalletError) -> String {
        switch error {
        case .backupTooLarge: AppLocalization.string("backup.error.tooLarge", locale: locale)
        case .unsupportedBackup: AppLocalization.string("backup.error.unsupported", locale: locale)
        case .invalidBackup: AppLocalization.string("backup.error.invalid", locale: locale)
        case .activeCylinderLimit(let limit): AppLocalization.string("backup.activeLimit", locale: locale, limit)
        }
    }
    private static var dateStamp: String { String(ISO8601DateFormatter().string(from: .now).prefix(10)) }
}

private struct HelpView: View {
    let steps: [LocalizedStringKey] = ["Add a cylinder with only its gas and capacity.", "Copy an existing cylinder when the details are similar.", "Tap a status whenever it changes.", "Record a refill or exchange; today and your currency are already selected.", "Return or archive a cylinder when it leaves your active inventory.", "Create a backup file before moving to a new phone."]
    var body: some View { List { ForEach(Array(steps.enumerated()), id: \.offset) { index, step in HStack(alignment: .top, spacing: 14) { Text("\(index + 1)").font(.headline).foregroundStyle(.tint).frame(width: 32, height: 32).background(Color.blue.opacity(0.08), in: Circle()); Text(step) } }; Section { Text("If you make a mistake, edit the cylinder or use Delete cylinder and Undo.").foregroundStyle(.secondary) } }.navigationTitle("Help").navigationBarTitleDisplayMode(.inline) }
}

private extension Result { var isSuccess: Bool { if case .success = self { true } else { false } } }
