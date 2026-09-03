# Welding Gas Wallet iOS guide

This is the authoritative native iOS application. It derives from `lrodeveloperr/Ios-shell`; do not replace it with Flutter, React Native, a WebView shell, or code from the obsolete Flutter repository.

## Product contract

- The approved browser preview is the visual and behavioral source of truth.
- Keep SwiftUI navigation, sheets, SF Symbols, keyboards, safe areas, Dynamic Type, VoiceOver, RTL, and iPhone/iPad adaptation native.
- Free users have at most three active cylinders. A verified monthly subscription unlocks unlimited active cylinders.
- This app contains no advertising SDK, banner slot, ad metadata, or advertising-consent UI. Do not leave an empty safe-area inset or reintroduce ads through a release workflow.
- The approved commercial price is US$1.99 per month. The app contains no geographic-pricing rules and must always display the price and currency returned by StoreKit instead of hard-coding US$1.99 into customer-facing UI.
- Cylinder records stay on-device. Native Files export/import is optional and purchase entitlement is never included.
- Display currency signs in the interface. Persist ISO currency codes only in the data layer; never silently convert or combine currencies.
- Preserve delete confirmation, 15-second Undo, Return/Archive, activity history, reminders, suppliers, search/filters, and the data-entry friction reductions.
- Privacy Policy and Terms are maintained externally. Do not invent policy copy.

## Localization release gate

- A language may appear in `supportedLanguages` only when its product-specific catalog exists and has exact key parity with English. A shared shell vocabulary or fallback English is not a translated app.
- Keep persisted enum/raw values stable, but never present raw values directly. Map statuses, relationships, lifecycle states, activity kinds and preset gases to localized display keys.
- Use locale-aware parsing and formatting for decimal input, money, quantities, dates and plurals. Never assemble sentences with English singular/plural branches.
- Review welding terminology for the target region, not only the language. Latin American Spanish uses `cilindro`, `recarga`, `proveedor` and `fuera del taller` in this app.
- Validate Dynamic Type/text expansion and bidirectional layout before enabling a locale. RTL locales require an explicit RTL QA pass.
- Notification copy, accessibility labels, validation errors, empty states, purchase copy and legal-link labels are part of the catalog.
- Published legal documents must be available and appropriate for every enabled locale, or the app must clearly disclose the document language. Never imply translated legal coverage that does not exist.
- Run `bash scripts/validate-shell.sh --app`; localization parity is a release-blocking check.

## Source map

- Product model and persistence: `Shell/Features/WalletStore.swift`
- Product screens: `Shell/Features/FeatureView.swift`
- Settings, currency and backup: `Shell/Features/SettingsView.swift`
- App entry point: `Shell/App/WeldingGasWalletApp.swift`
- Navigation shell: `Shell/App/ShellRootView.swift`
- Monetization/legal/destinations: `Shell/App/ShellConfiguration.swift`
- StoreKit: `Shell/Services/PurchaseService.swift`, `Shell/Services/AccessController.swift`
- Validation: `scripts/validate-shell.sh`

## Release control

- All GitHub workflows must remain `workflow_dispatch` only.
- Never run or dispatch an iOS archive, TestFlight upload, or paid hosted build without explicit user authorization.
- Release validation must reject Google Mobile Ads/UMP linkage, GAD/SKAdNetwork metadata, ad unit IDs, ad consent UI, and reserved banner spacing.
- The monthly product must exist in App Store Connect with the configured identifier, a one-month duration, and the approved US$1.99 base price. The app must not implement location-based pricing behavior.
- Run `bash scripts/validate-shell.sh --app` for code-only structural checks.
