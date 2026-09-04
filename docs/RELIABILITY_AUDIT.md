# Reliability audit and regression guidance

This checklist records the failure modes fixed in the native iOS shell. Future changes must preserve the visual design and keep these guarantees.

## Resolved failure modes

| Area | Failure | Required behavior |
| --- | --- | --- |
| Touch | Tests could tap child text and hide a partially working button | Tests locate the control element, verify it is hittable and tap near both edges; controls are at least 44×44 points |
| Storage | A write error still appeared successful | Validate and persist atomically before success; roll back memory and show the error on failure |
| Recovery | Damaged local JSON silently opened as an empty wallet | Preserve a timestamped recovery copy and report the problem |
| Restore | Imported state could leave ghost reminders or unsorted activity | Reject invalid snapshots without mutation, cancel all prior requests, sort activity and schedule only active records |
| Access | Inactive or excess free cylinders could still mutate | Enforce lifecycle and three-cylinder access inside every store mutation, restore and Undo |
| Input | Infinite capacities, invalid unit/reference data, unit-only exchanges and oversized costs could enter storage | Reject non-finite/out-of-range/inconsistent values in `WalletStore` |
| Reminders | Denied permission, past dates or scheduling errors looked successful | Keep the form open, show failure, and persist only after scheduling succeeds |
| Purchases | Repeated purchase/restore/retry taps could overlap | Operations are single-flight and conflicting controls remain disabled until completion |
| Store catalog | StoreKit could return no matching product and make “Retry App Store” appear inert | Explain the unavailable catalog, show a localized “Try again,” show loading during retry and alert if the catalog remains empty |
| Localization | Navigation headers remained cached in English after the app language changed | Resolve all static navigation titles directly from `LanguageController` and render the localized result verbatim |
| Currency | The complete ISO list exposed obsolete/special units and some rows showed three-letter codes | Intersect common ISO currencies with current system-locale currencies and display conventional signs while storing ISO codes internally |
| Validation | Hosted macOS runners without `rg` silently skipped source checks | Fall back to stock `grep`/`perl`; validation must execute or fail, never skip |

The 2026-09-04 TestFlight empty-catalog incident also had an external configuration blocker: App Store Connect required Review Information for the first annual subscription. The physical-phone StoreKit confirmation screenshot was uploaded to the private Review Information field on 2026-09-04, while the separate public promotional-image field was deliberately left empty. Correct code cannot manufacture StoreKit product metadata. Release evidence must verify product ID, price matrix, availability, paid agreement and required review metadata before treating an empty response as a transient network failure.

## Required verification

- Run `bash scripts/validate-shell.sh --app` and require a clean result.
- Run the WalletStore XCTest suite on an available Xcode host.
- Run XCUITest control journeys with child-label fallback forbidden and edge taps enabled.
- Exercise add, edit, duplicate, status, refill, exchange, cost, reminder, return, archive, delete, Undo, backup, restore, language, currency, legal links, purchase, restore purchase and retry once with VoiceOver and once at a large Dynamic Type size.
- Re-test persistence failure, malformed restore, Pro expiry above three active cylinders, notification denial and a purchase action tapped rapidly.
- Verify an empty StoreKit product response shows an explanation, one retry loading transition and explicit failure feedback; confirm it never unlocks Pro.
- Switch languages while each root and Settings screen is visible and confirm every navigation header updates immediately.
- Confirm the currency picker excludes `XXX`, `XAU`, `XDR` and known withdrawn currencies, and that no selectable row displays its ISO code as the sign.
