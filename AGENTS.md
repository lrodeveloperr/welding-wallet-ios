# Welding Gas Wallet iOS guide

This is the authoritative native iOS application. It derives from `lrodeveloperr/Ios-shell`; do not replace it with Flutter, React Native, a WebView shell, or code from the obsolete Flutter repository.

## Product contract

- The approved browser preview is the visual and behavioral source of truth.
- Keep SwiftUI navigation, sheets, SF Symbols, keyboards, safe areas, Dynamic Type, VoiceOver, RTL, and iPhone/iPad adaptation native.
- Free users have at most three active cylinders and a permanently reserved lower banner area.
- A verified monthly subscription removes both the banner and cylinder limit. Its commercial reference price is US$1.99 per month, with territory-specific prices configured in App Store Connect. The app must always display the localized StoreKit price and must never hard-code US$1.99 into customer-facing UI.
- Cylinder records stay on-device. Native Files export/import is optional and purchase entitlement is never included.
- Display currency signs in the interface. Persist ISO currency codes only in the data layer; never silently convert or combine currencies.
- Preserve delete confirmation, 15-second Undo, Return/Archive, activity history, reminders, suppliers, search/filters, and the data-entry friction reductions.
- Privacy Policy and Terms are maintained externally. Do not invent policy copy.

## Source map

- Product model and persistence: `Shell/Features/WalletStore.swift`
- Product screens: `Shell/Features/FeatureView.swift`
- Settings, currency and backup: `Shell/Features/SettingsView.swift`
- App entry point: `Shell/App/WeldingGasWalletApp.swift`
- Navigation shell: `Shell/App/ShellRootView.swift`
- Monetization/legal/destinations: `Shell/App/ShellConfiguration.swift`
- Ads/consent: `Shell/Services/AdaptiveAdBanner.swift`, `Shell/Services/AdConsentService.swift`
- StoreKit: `Shell/Services/PurchaseService.swift`, `Shell/Services/AccessController.swift`
- Validation: `scripts/validate-shell.sh`

## Release control

- All GitHub workflows must remain `workflow_dispatch` only.
- Never run or dispatch an iOS archive, TestFlight upload, or paid hosted build without explicit user authorization.
- Production ads require publisher-owned AdMob app/banner IDs.
- The monthly product must exist in App Store Connect with the configured identifier, a one-month duration, a US$1.99 reference price, and geo-priced territory equivalents.
- Run `bash scripts/validate-shell.sh --app` for code-only structural checks.
