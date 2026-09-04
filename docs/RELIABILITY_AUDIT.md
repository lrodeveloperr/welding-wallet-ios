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

## Required verification

- Run `bash scripts/validate-shell.sh --app` and require a clean result.
- Run the WalletStore XCTest suite on an available Xcode host.
- Run XCUITest control journeys with child-label fallback forbidden and edge taps enabled.
- Exercise add, edit, duplicate, status, refill, exchange, cost, reminder, return, archive, delete, Undo, backup, restore, language, currency, legal links, purchase, restore purchase and retry once with VoiceOver and once at a large Dynamic Type size.
- Re-test persistence failure, malformed restore, Pro expiry above three active cylinders, notification denial and a purchase action tapped rapidly.
