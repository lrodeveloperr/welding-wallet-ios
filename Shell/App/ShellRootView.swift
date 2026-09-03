import SwiftUI

struct ShellRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let featureProvider: any FeatureCanvasProviding
    private let wallet: WalletStore
    @State private var model: ShellModel

    init(
        featureProvider: any FeatureCanvasProviding,
        wallet: WalletStore,
        model: ShellModel = ShellModel()
    ) {
        self.featureProvider = featureProvider
        self.wallet = wallet
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            if let startupMessage = model.startupMessage {
                ContentUnavailableView {
                    Label("startup.error.title", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(startupMessage)
                }
            } else {
                shell
            }
        }
        .environment(model)
        .environment(model.language)
        .environment(\.locale, model.language.locale)
        .environment(\.layoutDirection, model.language.layoutDirection)
        .sheet(isPresented: $model.settingsPresented) {
            NavigationStack { SettingsView(model: model, wallet: wallet) }
                .environment(model)
                .environment(model.language)
                .environment(\.locale, model.language.locale)
                .environment(\.layoutDirection, model.language.layoutDirection)
        }
#if DEBUG
        .sheet(isPresented: $model.labPresented) {
            NavigationStack { ShellLabView() }
                .environment(model)
                .environment(model.language)
                .environment(\.locale, model.language.locale)
                .environment(\.layoutDirection, model.language.layoutDirection)
        }
#endif
        .sheet(isPresented: $model.paywallPresented) {
            NavigationStack { PaywallView(showsDoneButton: true) }
                .environment(model)
                .environment(model.language)
                .environment(\.locale, model.language.locale)
                .environment(\.layoutDirection, model.language.layoutDirection)
        }
        .task {
            await model.start()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.access.purchases.refreshEntitlements() } }
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
