# Workshop Pearl — GoodUse native acceptance checklist

This checklist is a release gate, not a scorecard. A tester may mark **ALL CLEAR**
only when every applicable item has objective evidence and there are no open
P0/P1 findings. Record **FAIL**, not “mostly passes”, for missing evidence.

## Evidence header

- Platform / OS / device or simulator:
- Commit SHA:
- Workflow run and artifact:
- App version / build:
- Locale(s), text scale, display size, orientation:
- Store sandbox account and product state:
- Tester / date:

## 1. Workshop Pearl visual system

- [ ] Background `#EEF6FF`; surface `#FFFFFF`; secondary surface `#F7FBFF`.
- [ ] Text `#163451`; muted `#698098`; line `#D7E6F3`.
- [ ] Primary `#247BD1`; primary soft `#E7F3FF`.
- [ ] Success `#278E67/#E7F6EF`, warning `#AA7114/#FFF5DD`, error
      `#BF414A/#FFF0F1`; warm accent is reserved for due/attention states.
- [ ] Card shadow matches `0 8px 22px rgba(47,94,139,.07)` and hero shadow
      matches `0 14px 34px rgba(38,83,127,.11)` without muddy elevation.
- [ ] 16dp screen gutter, 12dp compact gutter, 14dp normal gap, 16dp card
      radius, 24dp hero radius, 56dp bars, 62dp dominant CTA.
- [ ] Every interactive target is at least 48x48dp; chips are at least 44dp.
- [ ] One visually dominant action per view; hierarchy remains obvious at a
      glance and matches the approved Workshop Pearl reference.
- [ ] Four stable thumb destinations: Wallet, Activity, Spend, Settings.
- [ ] No default-Material-looking, flat, lifeless, or gratuitously ornamental
      screen; surfaces, typography, iconography, spacing, and motion cohere.

## 2. First run and task fit

- [ ] First-run scope card says records stay on-device unless exported and
      accurately states the safety exclusions.
- [ ] Continue is not mislabelled as forced privacy consent; Privacy, Terms,
      and Safety & scope are visible but optional.
- [ ] Currency, mass unit, volume unit, and language are understandable and
      safely defaulted; the user can change them later in Settings.
- [ ] Empty Wallet makes the next action obvious without implying ownership,
      safety, fillability, inspection status, gas suitability, or supplier
      acceptance.
- [ ] A cylinder can be created, viewed, edited, archived/returned, restored
      through import, and permanently deleted with clear consequences.
- [ ] Refill, exchange, cost, relationship, supplier, note, and reminder flows
      are reachable from the cylinder context with no data loss.
- [ ] The #4 cylinder paywall preserves the complete draft; closing it keeps
      free use intact; a verified purchase resumes without duplicate records.
- [ ] Downgrade keeps all data and deterministically selects the three free
      editable current cylinders; locked records are clear and non-destructive.
- [ ] Activity and Spend are useful with zero, one, and many records.
- [ ] Settings contains language, units, currency, reminders, plan/access,
      backup/import/export, privacy/legal/support, app version, and confirmed
      Delete all local data.

## 3. States, navigation, and resilience

- [ ] Test empty, loading, normal, busy, success, validation error, store
      unavailable, pending purchase, cancelled purchase, restored purchase,
      expired Android access, locked cylinder, malformed import, and offline.
- [ ] System Back / swipe-back / Escape closes the top-most transient view,
      preserves drafts where promised, and never exits unexpectedly.
- [ ] Every modal, sheet, dialog, menu, picker, deep link, and external-return
      direction was exercised end to end.
- [ ] Repeated taps, rapid navigation, rotation/resizing, background/resume,
      process restart, and interrupted operations do not duplicate or lose data.
- [ ] Destructive actions require explicit confirmation and state exact scope.
- [ ] Legal links fail safely if offline; bundled concise scope remains usable.
- [ ] No horizontal scrolling or clipped essential action at 200% text.
- [ ] Keyboard and visible focus order are logical where supported.

## 4. Accessibility and localization

- [ ] Screen reader labels, roles, values, headings, live status/error messages,
      and traversal order are meaningful; icons never carry meaning alone.
- [ ] Contrast passes WCAG AA in every semantic state, including disabled and
      selected controls.
- [ ] All 30 exact locale catalogs load with exact key/placeholder parity and
      no runtime English fallback.
- [ ] A deliberately missing/corrupt supported catalog shows that locale's
      separately compiled emergency copy; Arabic is RTL and no supported
      locale silently receives English recovery text.
- [ ] Arabic mirrors layout and navigation correctly while numbers, product
      identifiers, currency, and mixed-direction values remain intelligible.
- [ ] CJK, Indic, Thai, Vietnamese, German, Finnish, and other expansion-heavy
      locales were checked for truncation and culturally incorrect copy.
- [ ] Store-returned localized prices are never concatenated into ambiguous
      billing claims; period, renewal, no-trial, and one-time terms are clear.

## 5. Privacy, safety, and policy

- [ ] No account, ads, analytics, tracker, developer cloud, broad media access,
      location, contacts, microphone, call-log, or advertising-ID dependency.
- [ ] Notification permission is requested just in time after an explanation;
      denial leaves a recoverable path.
- [ ] Backup import/export uses system pickers/share surfaces and requests no
      broad file or media permission.
- [ ] Privacy, Terms, Safety & scope, Support, and deletion URLs open the exact
      live product pages and return HTTP 200.
- [ ] Store privacy/data-safety answers match the final binary SDK, permission,
      and observed network evidence.
- [ ] Backup/export copy accurately says the chosen destination controls its
      copy; deletion does not claim to erase exports or store purchase history.

## 6. Revenue integrity

- [ ] Android only queries monthly
      `com.gooduse.weldinggaswallet.pro.monthly` and annual
      `com.gooduse.weldinggaswallet.pro.annual`; annual is selected by default.
- [ ] Current Play Console evidence proves exactly one candidate per SKU:
      base plan `annual`, no offer ID/tags/installment, one non-zero full-price
      infinitely recurring `P1Y` phase; and base plan `monthly` with the same
      restrictions and one `P1M` phase. Any trial, introductory phase, extra
      offer, or extra base plan is a release-blocking mismatch and the app must
      fail closed. This item remains **BLOCKED** until console export/screenshots
      and closed-track results are attached to the exact reviewed build.
- [ ] Android shows store-returned prices and exact auto-renewal/no-trial/cancel
      language; purchase CTA identifies subscription cadence.
- [ ] Android grants access only after Play reports purchased and the signed
      response/token/product are validated; pending, cancelled, invalid,
      mismatched, replayed, and unavailable responses grant nothing.
- [ ] Android Kotlin/JCA known-valid and tampered RSA/SHA-1 fixtures pass; the
      generated MethodChannel fails closed when its key or signature is absent,
      malformed, oversized, or unavailable.
- [ ] Android acknowledgement/completion occurs after validation; restore,
      renewal, grace/hold, expiry, refund/revocation, reinstall, offline bounded
      continuity, and downgrade were exercised in a Play test track.
- [ ] iOS only queries non-consumable
      `com.gooduse.weldinggaswallet.pro.lifetime`, shows the store price and
      one-time/no-subscription language, and exposes Restore Purchases.
- [ ] iOS grants access only for a verified StoreKit transaction matching the
      exact product; pending, cancelled, unverified, revoked, and mismatched
      transactions grant nothing; completion occurs after verification.
- [ ] iOS purchase, Ask to Buy/pending, cancel, restore, reinstall, refund/
      revocation, store unavailable, and duplicate update states were exercised
      with StoreKit sandbox/TestFlight evidence.
- [ ] No fake/preview grant path is reachable in a production build and no
      price or entitlement is trusted from import/backup.

## 7. Artifact and release evidence

- [ ] Static analysis, randomized unit/widget tests, and native integration
      tests pass from a clean checkout at the recorded SHA.
- [ ] Android APK/AAB package ID, target SDK, permissions, signature, certificate
      fingerprint, dependency inventory, and hashes are recorded.
- [ ] iOS archive bundle/team/build ID, minimum OS, signing, privacy manifests,
      icon alpha/size, dependency inventory, and hashes are recorded.
- [ ] App Store Connect export-compliance answers/evidence match the final iOS
      binary; `ITSAppUsesNonExemptEncryption` is not asserted merely to bypass
      TestFlight's Missing Compliance state.
- [ ] Legal/policy, localization, Android UX, and iOS UX reviewers are
      independent of the implementation owner and signed their exact checklists.
- [ ] Every P0/P1 was fixed and the affected checklist was rerun; accepted risk
      is never used to waive a P0/P1.

## Decision

- [ ] **ALL CLEAR** — all applicable checks passed with linked evidence.
- [ ] **FAIL** — findings below block release.

Findings / evidence links:
