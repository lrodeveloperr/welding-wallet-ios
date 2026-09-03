import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let model: ShellModel
    let wallet: WalletStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false
    @State private var deletePhrase = ""

    var body: some View {
        List {
            if !model.access.isEntitled {
                Section { NavigationLink { PaywallView() } label: { SettingsLabel("Upgrade", subtitle: "Remove ads and cylinder limit", symbol: "sparkles") }.accessibilityIdentifier("shell.settings.upgrade") }
            }
            Section {
                NavigationLink { LanguageView() } label: { SettingsLabel("Language", subtitle: "Choose the app language", symbol: "globe") }
                NavigationLink { CurrencyView(wallet: wallet) } label: { SettingsLabel("Currency", subtitle: "\(wallet.currencySign(for: wallet.defaultCurrency)) · \(wallet.currencyOverride == nil ? "Automatic" : "Selected")", symbol: "dollarsign.circle") }
                NavigationLink { BackupView(wallet: wallet) } label: { SettingsLabel("Backup", subtitle: "Optional native file backup", symbol: "externaldrive.badge.icloud") }
                NavigationLink { HelpView() } label: { SettingsLabel("Help", subtitle: "Simple numbered guide", symbol: "questionmark.circle") }
                if model.access.configuration.includesAdvertising && model.ads.isPrivacyOptionsRequired {
                    Button { Task { await model.ads.presentPrivacyOptions() } } label: { SettingsLabel("Ad privacy choices", subtitle: nil, symbol: "hand.raised.square") }
                }
            }
            Section {
                Link(destination: ShellConfiguration.legal.privacyURL) { SettingsLabel("Privacy policy", subtitle: "Opens in your browser", symbol: "hand.raised.shield") }
                Link(destination: ShellConfiguration.legal.termsURL) { SettingsLabel("Terms of use", subtitle: "Opens in your browser", symbol: "doc.text") }
            }
            Section { Button(role: .destructive) { showDelete = true } label: { SettingsLabel("Delete all data", subtitle: "Erase this wallet from this device", symbol: "trash") } }
            Section { Text("Welding Gas Wallet · Cylinder records stay on this device").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .alert("Delete all data?", isPresented: $showDelete) {
            TextField("Type DELETE", text: $deletePhrase).textInputAutocapitalization(.characters)
            Button("Delete all data", role: .destructive) { if deletePhrase.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE" { wallet.deleteAllData(); dismiss() }; deletePhrase = "" }.disabled(deletePhrase.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() != "DELETE")
            Button("Cancel", role: .cancel) { deletePhrase = "" }
        } message: { Text("This removes cylinders, suppliers, costs, activity, reminders and preferences. Purchases and separately saved backup files are not deleted.") }
    }
}

private struct SettingsLabel: View {
    let title: String; let subtitle: String?; let symbol: String
    init(_ title: String, subtitle: String? = nil, symbol: String) { self.title = title; self.subtitle = subtitle; self.symbol = symbol }
    var body: some View { Label { VStack(alignment: .leading, spacing: 2) { Text(title).foregroundStyle(.primary); if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) } } } icon: { Image(systemName: symbol).foregroundStyle(.tint).frame(width: 28) } }
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
    @State private var query = ""
    private var codes: [String] { Locale.Currency.isoCurrencies.map(\.identifier).filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) || (Locale.current.localizedString(forCurrencyCode: $0) ?? "").localizedCaseInsensitiveContains(query) }.sorted() }
    var body: some View {
        List {
            Section { Button { wallet.setCurrency(nil) } label: { HStack { Text(wallet.currencySign(for: wallet.automaticCurrency)).frame(width: 34); VStack(alignment: .leading) { Text("Automatic"); Text("Device region").font(.caption).foregroundStyle(.secondary) }; Spacer(); if wallet.currencyOverride == nil { Image(systemName: "checkmark.circle.fill") } } } }
            Section { ForEach(codes, id: \.self) { code in Button { wallet.setCurrency(code) } label: { HStack { Text(wallet.currencySign(for: code)).frame(width: 34); Text(Locale.current.localizedString(forCurrencyCode: code) ?? "Currency").foregroundStyle(.primary); Spacer(); if wallet.currencyOverride == code { Image(systemName: "checkmark.circle.fill") } } } } }
        }.searchable(text: $query, prompt: "Search currencies").navigationTitle("Currency").navigationBarTitleDisplayMode(.inline)
    }
}

private struct BackupView: View {
    @Bindable var wallet: WalletStore
    @State private var exporting = false; @State private var importing = false; @State private var document = WalletBackupDocument(); @State private var message = ""
    var body: some View {
        List {
            Section { Label("Keep a file copy", systemImage: "externaldrive.badge.icloud").font(.headline); Text("Use the native file picker to save to iCloud Drive, On My iPhone, or another Files location.").foregroundStyle(.secondary) }
            Section { Button("Save backup file", systemImage: "square.and.arrow.up") { do { document = WalletBackupDocument(data: try wallet.exportData()); exporting = true } catch { message = error.localizedDescription } }; Button("Restore backup file", systemImage: "square.and.arrow.down") { importing = true } }
            if !message.isEmpty { Section { Text(message) } }
            Section { Label("Backup files never include purchase entitlement.", systemImage: "lock") }
        }
        .navigationTitle("Backup").navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "welding-wallet-backup-\(Self.dateStamp)") { result in message = result.isSuccess ? "Backup file created" : "Backup was not saved" }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in do { let url = try result.get(); guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }; defer { url.stopAccessingSecurityScopedResource() }; try wallet.restore(from: Data(contentsOf: url)); message = "Backup restored" } catch { message = error.localizedDescription } }
    }
    private static var dateStamp: String { String(ISO8601DateFormatter().string(from: .now).prefix(10)) }
}

private struct HelpView: View {
    let steps = ["Add a cylinder with only its gas and capacity.", "Copy an existing cylinder when the details are similar.", "Tap a status whenever it changes.", "Record a refill or exchange; today and your currency are already selected.", "Return or archive a cylinder when it leaves your active inventory.", "Create a backup file before moving to a new phone."]
    var body: some View { List { ForEach(Array(steps.enumerated()), id: \.offset) { index, step in HStack(alignment: .top, spacing: 14) { Text("\(index + 1)").font(.headline).foregroundStyle(.tint).frame(width: 32, height: 32).background(Color.blue.opacity(0.08), in: Circle()); Text(step) } }; Section { Text("If you make a mistake, edit the cylinder or use Delete cylinder and Undo.").foregroundStyle(.secondary) } }.navigationTitle("Help").navigationBarTitleDisplayMode(.inline) }
}

private extension Result { var isSuccess: Bool { if case .success = self { true } else { false } } }
