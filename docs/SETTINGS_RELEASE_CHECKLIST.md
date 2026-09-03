# Welding Gas Wallet Settings release checklist

This is the source-level acceptance gate for Settings. Device and StoreKit checks remain mandatory before App Store submission, but they are intentionally not run during code-only updates.

## Product and presentation

- [x] Settings opens through an explicitly injected model, language controller and locale.
- [x] The navigation title resolves from the currently selected app locale instead of a cached English display literal.
- [x] Every visible Settings title, subtitle, footer and destructive warning is Welding Gas Wallet copy; no sample, shell-lab or "belongs here" placeholder is presented.
- [x] Privacy Policy, Terms of Use, Support, Data Deletion and Safety Notice buttons use plain button styling. Their titles are primary text, subtitles are secondary text and only icons use tint, matching the navigation rows above.
- [x] Legal controls open the configured product-specific HTTPS destinations rather than embedded draft text.
- [x] Backup, restore and deletion copy accurately distinguishes local wallet data, external backup files and App Store entitlement.

## Subscription truth table

| Verified condition | Settings presentation | Manage Subscription |
|---|---|---|
| Checking | Neutral hourglass and localized checking copy | Hidden |
| Never subscribed / expired | Upgrade only | Hidden |
| Revoked / refunded | Upgrade only | Hidden |
| Active, auto-renew on | Success seal and renewal date | Shown |
| Active, auto-renew off | Success seal and paid-through date | Shown |
| Billing Grace Period | Warning icon and verified grace date | Shown |
| Billing retry after grace | Warning icon and payment-recovery copy | Shown |
| Valid offline cache | Neutral verified seal and cache expiry | Shown |

- [x] Inactive customers never see a success tick, a blank status card or an irrelevant Manage Subscription action.
- [x] The upgrade row is suppressed while StoreKit is checking and during billing recovery.
- [x] All displayed dates use the selected locale.
- [x] Cancellation preserves unlimited access through the verified paid-through date.
- [x] Lapse never deletes data: the customer selects three manageable active cylinders and excess records remain visible/read-only with limit-reducing actions available.

## Localization and culture

- [x] All 31 selectable catalogs have exact 288-key parity and matching format placeholders.
- [x] Every language is presented under its native autonym; regional/script fallback is explicit rather than accidental.
- [x] The 29 added catalogs combine full automated coverage, matching previously reviewed product translations, the shared reviewed baseline and enforced welding terminology.
- [x] Subscription and inactive-status labels use locale-specific nouns and matching grammar rather than template vocabulary.
- [ ] A fluent regional reviewer validates every added catalog in screen context; generated coverage is not represented as native approval.
- [x] Latin American welding terminology uses `cilindro`, `recarga`, `proveedor`, `poco gas` and `fuera del taller` in the relevant product states.
- [x] StoreKit owns customer-facing currency and price localization; Settings contains no hard-coded US-dollar price.
- [x] Persisted record values remain canonical while user-facing statuses, lifecycle states, gases, errors and actions resolve through localized display keys.
- [x] Locale infrastructure explicitly changes SwiftUI layout direction for Arabic, Urdu and Hebrew at selection time, including presented sheets.
- [ ] On-device pass: switch every enabled language while Settings is open and confirm the title and every visible row change with no stray English.
- [ ] On-device pass: check Settings at accessibility text sizes and verify wrapping, hit targets and VoiceOver order.
- [ ] On-device pass: verify each subscription condition with StoreKit test accounts, including cancellation and expiration.

The final three items are deliberately unchecked until a run is explicitly authorized.
