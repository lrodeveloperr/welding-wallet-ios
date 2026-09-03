# Welding Gas Wallet iOS guide

This is the authoritative native iOS application. It derives from `lrodeveloperr/Ios-shell`; do not replace it with Flutter, React Native, a WebView shell, or code from the obsolete Flutter repository.

## Product contract

- The approved browser preview is the visual and behavioral source of truth.
- Keep SwiftUI navigation, sheets, SF Symbols, keyboards, safe areas, Dynamic Type, VoiceOver, RTL, and iPhone/iPad adaptation native.
- Free users have at most three active cylinders. A verified monthly subscription unlocks unlimited active cylinders.
- Cancelling auto-renewal does not end Pro before the verified paid-through date. Verified Billing Grace Period remains Pro; billing retry after grace, expiry and revocation do not.
- If Pro lapses with more than three active cylinders, never delete or silently archive data. The customer selects three cylinders to keep managing; excess active cylinders remain visible/read-only and may be exported, returned, archived or deleted. A freed managed slot may be assigned once, but the three selections cannot be swapped repeatedly to simulate unlimited use.
- Enforce the limit inside `WalletStore` for add, duplicate, edit, status, service, reminder, restore and Undo—not only in SwiftUI. Forms must read current entitlement again when Save is pressed.
- This app contains no advertising SDK, banner slot, ad metadata, or advertising-consent UI. Do not leave an empty safe-area inset or reintroduce ads through a release workflow.
- The approved commercial price is US$1.99 per month. The app contains no geographic-pricing rules and must always display the price and currency returned by StoreKit instead of hard-coding US$1.99 into customer-facing UI.
- Cylinder records stay on-device. Native Files export/import is optional and purchase entitlement is never included.
- Display currency signs in the interface. Persist ISO currency codes only in the data layer; never silently convert or combine currencies.
- Preserve delete confirmation, 15-second Undo, Return/Archive, activity history, reminders, suppliers, search/filters, and the data-entry friction reductions.
- Privacy Policy and Terms are maintained externally. Do not invent policy copy.
- Launch directly into the cylinder wallet. Do not require a privacy-policy or terms acceptance screen; keep those documents available in Settings and on the subscription page.

## Localization release gate

- A language may appear in `supportedLanguages` only when its product-specific catalog exists and has exact key parity with English. A shared shell vocabulary or fallback English is not a translated app.
- Keep persisted enum/raw values stable, but never present raw values directly. Map statuses, relationships, lifecycle states, activity kinds and preset gases to localized display keys.
- Use locale-aware parsing and formatting for decimal input, money, quantities, dates and plurals. Never assemble sentences with English singular/plural branches.
- Review welding terminology for the target region, not only the language. Latin American Spanish uses `cilindro`, `recarga`, `proveedor` and `fuera del taller` in this app.
- Translate cylinder states by domain meaning, not word-for-word. In Latin American Spanish, a low-gas cylinder `tiene poco gas`; never translate English “low” as `está bajo`. Use `fuera del taller` for off-site/away when no more specific location is known.
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
- The production-logic TestFlight workflow must never accept or compile a screenshot/free fixture profile. Screenshot builds use a separately named workflow and confirmation phrase.
- Never run or dispatch an iOS archive, TestFlight upload, or paid hosted build without explicit user authorization.
- Release validation must reject Google Mobile Ads/UMP linkage, GAD/SKAdNetwork metadata, ad unit IDs, ad consent UI, and reserved banner spacing.
- The monthly product must exist in App Store Connect with the configured identifier, a one-month duration, and the approved US$1.99 base price. The app must not implement location-based pricing behavior.
- Use one subscription group and one level for the single monthly product. Localize the group and product display metadata in English and Latin American Spanish, attach the review screenshot/notes, and submit the first subscription with the app version.
- Settings must show verified subscription status and Apple's management surface. The paywall must make StoreKit's full localized renewal price the most prominent pricing element; billing retry routes to management instead of another purchase.
- Run `bash scripts/validate-shell.sh --app` for code-only structural checks.
