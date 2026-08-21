# Welding Gas Wallet — Workshop Pearl

Premium local-first Android and iOS cylinder record wallet by GoodUse Studios.
This repository uses the approved Workshop Pearl skin and the GoodUse product
grammar: a calm pearl-blue surface system, one dominant action per view, stable
thumb navigation, complete state handling, and a settings-led workflow.

## Product contract

- No GoodUse Studios account, ads, analytics SDK, tracker, or cylinder-record
  cloud database.
- The first three current cylinder records remain editable for free. A fourth
  draft is preserved behind the platform purchase flow.
- Android: annual subscription selected by default, monthly alternative, no
  trial. Product IDs are fixed in the domain core. Play Console must expose
  exactly one purchasable candidate for each SKU: base plan `annual` with no
  offer ID/tags/installment and one non-zero, full-price, infinitely recurring
  `P1Y` phase; base plan `monthly` with the same restrictions and one `P1M`
  phase. Any trial, introductory phase, extra offer, or extra base plan makes
  product loading fail closed.
- iOS: one-time non-consumable lifetime purchase. Product ID is fixed in the
  domain core.
- Prices are always returned by Google Play or the App Store; this project does
  not construct a currency price.
- Exact complete catalogs are required for 30 locales. Catalog mismatch fails
  closed instead of silently substituting English; a separately compiled,
  exact-locale emergency surface remains available if an ARB is corrupt.
- The app records user-entered facts. It does not determine ownership,
  fillability, inspection/test status, cylinder safety, gas suitability, legal
  compliance, or supplier acceptance.

## Source and generated hosts

Flutter `3.44.8` is pinned by GitHub Actions. The reviewed Dart source is shared
between platforms. Clean Android and iOS host projects are generated in CI and
then hardened by `tool/configure_hosts.py`; no WebView or web preview is shipped.

The Android QA workflow runs static analysis, randomized unit/widget tests, an
emulator end-to-end test, APK identity/signature inspection, and produces a
sideloadable debug APK plus audit evidence. A separate protected workflow can
create a signed production AAB only from `main` when all required secrets exist.

The iOS CI workflow runs the equivalent simulator and unsigned-archive gates.
The protected TestFlight workflow uploads only from `main`, with an explicit
dispatch phrase and App Store Connect API credentials supplied as protected
GitHub environment secrets. It also requires
`APPLE_EXPORT_COMPLIANCE_EVIDENCE_ID`; CI deliberately does not hardcode
`ITSAppUsesNonExemptEncryption` without the Account Holder's current App Store
Connect questionnaire evidence.

Google Play's RSA/SHA-1 signature primitive runs only in the generated Android
host through Kotlin/JCA. Dart still checks the exact signed package, SKU,
purchase token and purchase state before access, and then acknowledges only a
verified purchase. The shared Dart/iOS graph contains neither `basic_utils` nor
`pointycastle`; Android CI executes known-valid and tampered native fixtures.

## Public legal and support pages

- Privacy: <https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/privacy/>
- Terms: <https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/terms/>
- Safety and scope: <https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/disclaimer/>
- Support: <https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/support/>
- Local data deletion: <https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/deletion/>

These links are release requirements and must return HTTP 200 from the published
site before store submission.

## Release rule

An APK build is not evidence that real subscriptions work. Android revenue
clearance requires the signed AAB, configured Play products, and closed/internal
Play-track scenarios. iOS revenue clearance requires StoreKit sandbox/TestFlight
purchase, pending, cancel, restore, reinstall, and revocation evidence. See the
reviewed acceptance checklist. No reviewer may mark all-clear with missing
store evidence or an unresolved P0/P1 finding. The exact live Play Console
base-plan/offer configuration above remains blocked until exported console and
closed-track evidence are attached to the reviewed build.
