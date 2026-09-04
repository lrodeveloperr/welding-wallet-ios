# Welding Gas Wallet iOS guide

This is the authoritative native iOS application. It derives from `lrodeveloperr/Ios-shell`; do not replace it with Flutter, React Native, a WebView shell, or code from the obsolete Flutter repository.

## Product contract

- The approved browser preview is the visual and behavioral source of truth.
- Keep SwiftUI navigation, sheets, SF Symbols, keyboards, safe areas, Dynamic Type, VoiceOver, RTL, and iPhone/iPad adaptation native.
- Free users have at most three active cylinders. A verified annual subscription unlocks unlimited active cylinders.
- Cancelling auto-renewal does not end Pro before the verified paid-through date. Verified Billing Grace Period remains Pro; billing retry after grace, expiry and revocation do not.
- If Pro lapses with more than three active cylinders, never delete or silently archive data. The customer selects three cylinders to keep managing; excess active cylinders remain visible/read-only and may be exported, returned, archived or deleted. A freed managed slot may be assigned once, but the three selections cannot be swapped repeatedly to simulate unlimited use.
- Enforce the limit inside `WalletStore` for add, duplicate, edit, status, service, reminder, restore and Undo—not only in SwiftUI. Forms must read current entitlement again when Save is pressed.
- This app contains no advertising SDK, banner slot, ad metadata, or advertising-consent UI. Do not leave an empty safe-area inset or reintroduce ads through a release workflow.
- The approved commercial base price is US$19.99 per year. App Store Connect owns geographic storefront pricing; the app must display StoreKit's localized price, currency, and subscription period and must never calculate a price from device location or hard-code US$19.99 into customer-facing UI.
- Cylinder records stay on-device. Native Files export/import is optional and purchase entitlement is never included.
- Display currency signs in the interface. Persist ISO currency codes only in the data layer; never silently convert or combine currencies.
- Currency selectors must offer current, commonly used regional currencies only. Do not expose obsolete ISO currencies, precious-metal/accounting units, test codes, or ISO abbreviations as customer-facing symbols.
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
- Generated translation is a draft, never release evidence. Every user-visible string must be reviewed in product context for trade terminology, tone, Apple terminology, grammar and regional usage before its locale is exposed.
- Display language choices as native autonyms. Map language-region/script identifiers deliberately, and update SwiftUI `layoutDirection` explicitly when the in-app selection changes between LTR and Arabic, Urdu or Hebrew.
- Keep a per-locale PASS/FAIL matrix in `docs/LOCALIZATION_RELEASE_CHECKLIST.md`; a key-count check or blanket claim cannot replace cultural review.
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
- Reliability audit: `docs/RELIABILITY_AUDIT.md`

## Reliability and touchscreen gate

- Treat every visible control as a single full-surface target. Interactive labels must be at least 44×44 points, use `contentShape(Rectangle())` when the visual row is larger than its text, and remain tappable at the left, center, and right edges.
- UI tests must locate controls by the button/control accessibility element. Never fall back to tapping a child `Text` or `Image`, because that hides broken or partial hit regions.
- Every wallet mutation is transactional: validate first, persist atomically, then publish success and perform reminder side effects. On a write failure, roll back the in-memory mutation and expose an actionable error.
- Never decode malformed or inconsistent storage/backup data to an empty wallet. Preserve a recovery copy of damaged local data; reject a bad import without changing current records.
- Apply the three-active-cylinder policy, lifecycle read-only policy, finite numeric/range checks, unique IDs/serials, valid references, units and currencies inside `WalletStore`, including restore and Undo paths.
- Restore must sort activity, cancel reminders for records it removes, and reschedule only valid active reminders. Editing reminder copy must refresh its pending notification. Do not save a past reminder or claim success when notification authorization/scheduling fails.
- Purchase, restore and retry operations must be single-flight. Disable conflicting controls while work is active, never offer an already-owned product, and give explicit feedback when restore finds no entitlement.
- An empty StoreKit product response is an unavailable catalog state, not a silent success. Explain why purchase is unavailable, label recovery as a plain localized “Try again,” show loading while retrying, and report another empty response instead of appearing inert.
- A reliability change is incomplete without regression coverage for the failing store path and edge-of-control touchscreen taps. Run `bash scripts/validate-shell.sh --app`; run XCTest/XCUITest when Xcode is available.

## Release control

- All GitHub workflows must remain `workflow_dispatch` only.
- The production-logic TestFlight workflow must never accept or compile a screenshot/free fixture profile. Screenshot builds use a separately named workflow and confirmation phrase.
- Never run or dispatch an iOS archive, TestFlight upload, or paid hosted build without explicit user authorization.
- Release validation must reject Google Mobile Ads/UMP linkage, GAD/SKAdNetwork metadata, ad unit IDs, ad consent UI, and reserved banner spacing.
- The annual product must exist in App Store Connect as `com.gooduse.weldinggaswallet.pro.yearly`, with a one-year duration and a US$19.99 United States base price. Generate geographic storefront prices in App Store Connect, review every enabled storefront, and keep location-based pricing logic out of the app.
- Use one subscription group and one level for the single annual product. Localize the group and product display metadata in English and Latin American Spanish, attach the review screenshot/notes, and submit the first subscription with the app version.
- Keep App Store Connect subscription assets distinct. The private Review Information screenshot may show Apple's StoreKit/TestFlight confirmation sheet, including the system-rendered app icon. The public optional subscription image must remain empty unless a unique campaign asset is deliberately approved; never upload the app icon or an app screenshot there. Apple's system-rendered app icon is not an app-controlled paywall logo and must not be treated as a commerce-branding validation failure.
- Settings must show verified subscription status and Apple's management surface. The paywall must make StoreKit's full localized renewal price the most prominent pricing element; billing retry routes to management instead of another purchase.
- Settings must not manufacture a subscription state. Hide subscription status and Manage Subscription for customers with no current or recoverable subscription; show a neutral checking row while StoreKit resolves; show state-appropriate success/warning iconography and management only for active, grace, billing-retry or still-valid offline-cached states.
- Every Settings title and subtitle must be final product copy. No shell/sample/footer placeholder may remain. Button-backed rows must explicitly preserve the same primary-title and secondary-subtitle colors as navigation rows; only their icons use tint.
- Changing the in-app language must immediately update the Settings navigation title and all visible Settings copy. Keep only complete, culturally reviewed catalogs in the selector; never expose a broader language list by falling back to English.
- Resolve every static navigation title directly from `LanguageController` and present the result verbatim. Do not rely on `NavigationStack` to refresh a cached `LocalizedStringKey` after an in-app language change.
- Validation scripts must run on stock hosted macOS runners. If an optional search tool such as `rg` is missing, use a built-in fallback and fail closed; never silently skip a release check.
- Run `bash scripts/validate-shell.sh --app` for code-only structural checks.
