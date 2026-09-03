import SwiftUI

struct ShellRootView: View {
    private let featureProvider: any FeatureCanvasProviding
    private let wallet: WalletStore
#if SCREENSHOT_BUILD
    private let screenshotMode = true
    private let screenshotOnboarding = false
#elseif DEBUG
    private let screenshotMode = ProcessInfo.processInfo.arguments.contains("-welding.screenshotData")
    private let screenshotOnboarding = ProcessInfo.processInfo.arguments.contains("-welding.screenshotOnboarding")
#else
    private let screenshotMode = false
    private let screenshotOnboarding = false
#endif
    @State private var model: ShellModel
    @State private var legalConsent: LegalConsentStore

    init(
        featureProvider: any FeatureCanvasProviding,
        wallet: WalletStore,
        model: ShellModel = ShellModel(),
        legalConsent: LegalConsentStore = LegalConsentStore()
    ) {
        self.featureProvider = featureProvider
        self.wallet = wallet
        _model = State(initialValue: model)
        _legalConsent = State(initialValue: legalConsent)
    }

    var body: some View {
        Group {
            if screenshotOnboarding {
                OnboardingView(profile: ShellConfiguration.onboarding, isReconsent: false, onAccept: {})
            } else if let startupMessage = model.startupMessage {
                ContentUnavailableView {
                    Label("startup.error.title", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(startupMessage)
                }
            } else if !screenshotMode && legalConsent.requiresPresentation {
                OnboardingView(
                    profile: ShellConfiguration.onboarding,
                    isReconsent: legalConsent.isReconsent,
                    onAccept: legalConsent.acceptCurrentLegalVersion
                )
            } else {
                shell
            }
        }
        .environment(model)
        .environment(model.language)
        .environment(\.locale, model.language.locale)
        .sheet(isPresented: $model.settingsPresented) {
            NavigationStack { SettingsView(model: model, wallet: wallet) }
                .environment(model)
                .environment(model.language)
                .environment(\.locale, model.language.locale)
        }
#if DEBUG
        .sheet(isPresented: $model.labPresented) {
            NavigationStack { ShellLabView(onResetOnboarding: legalConsent.resetForTesting) }
                .environment(model)
                .environment(model.language)
                .environment(\.locale, model.language.locale)
        }
#endif
        .sheet(isPresented: $model.paywallPresented) {
            NavigationStack { PaywallView(showsDoneButton: true) }
                .environment(model)
                .environment(model.language)
                .environment(\.locale, model.language.locale)
        }
        .task {
            await model.start()
        }
    }

    @ViewBuilder
    private var shell: some View {
        if ShellConfiguration.destinations.count == 1, let destination = ShellConfiguration.destinations.first {
            destinationStack(destination)
        } else {
            TabView(selection: $model.selectedDestination) {
                ForEach(ShellConfiguration.destinations) { destination in
                    destinationStack(destination)
                    .tag(destination.id)
                    .tabItem {
                        if destination.id == "cylinders" {
                            Label("Cylinders", image: "CylinderTabIcon")
                        } else {
                            Label { Text(LocalizedStringKey(destination.titleKey)) } icon: { Image(systemName: destination.symbol) }
                        }
                    }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        }
    }

    private func destinationStack(_ destination: ShellDestination) -> some View {
        NavigationStack {
            FeatureCanvasHost(destination: destination, provider: featureProvider)
                .navigationTitle(LocalizedStringKey(destination.titleKey))
                .shellSettingsToolbar()
        }
    }
}

private extension View {
    func shellSettingsToolbar() -> some View { modifier(ShellSettingsToolbar()) }
}

private struct ShellSettingsToolbar: ViewModifier {
    @Environment(ShellModel.self) private var model

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("settings", systemImage: "gearshape") { model.settingsPresented = true }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("shell.settings")
            }
        }
    }
}
