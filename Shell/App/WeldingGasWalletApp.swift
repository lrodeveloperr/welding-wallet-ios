import SwiftUI

@main
struct WeldingGasWalletApp: App {
    @State private var wallet: WalletStore

    init() {
        _wallet = State(initialValue: WalletStore())
    }

    var body: some Scene {
        WindowGroup {
            ShellRootView(featureProvider: WeldingWalletFeatureProvider(store: wallet))
                .environment(wallet)
                .tint(ShellConfiguration.tint)
                .preferredColorScheme(.light)
        }
    }
}
