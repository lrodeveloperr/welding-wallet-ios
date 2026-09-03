import SwiftUI

@main
struct WeldingGasWalletApp: App {
    @State private var wallet: WalletStore

    init() {
#if SCREENSHOT_BUILD
        _wallet = State(initialValue: WalletStore.screenshotYear())
#elseif DEBUG
        let screenshotMode = ProcessInfo.processInfo.arguments.contains("-welding.screenshotData")
        let screenshotOpenSlot = ProcessInfo.processInfo.arguments.contains("-welding.screenshotOpenSlot")
        _wallet = State(initialValue: screenshotMode ? WalletStore.screenshotYear(openSlot: screenshotOpenSlot) : WalletStore())
#else
        _wallet = State(initialValue: WalletStore())
#endif
    }

    var body: some Scene {
        WindowGroup {
            ShellRootView(featureProvider: WeldingWalletFeatureProvider(store: wallet), wallet: wallet)
                .environment(wallet)
                .tint(ShellConfiguration.tint)
                .preferredColorScheme(.light)
        }
    }
}
