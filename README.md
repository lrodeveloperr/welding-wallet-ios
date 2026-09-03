# Welding Gas Wallet — iOS

Native Swift 6 and SwiftUI implementation of the approved Welding Gas Wallet MVP for iPhone and iPad. Flutter is not used.

The app is an offline, cylinder-only wallet with search and status filters, refill/exchange/cost history, suppliers, reminders, duplicate entry, reversible deletion, archive/return, native backup files, 30 selectable languages, automatic-region currency with manual override, a three-active-cylinder free limit, an anchored lower ad banner, and a monthly StoreKit subscription that removes the banner and limit.

Currency values are shown with locale-appropriate signs such as `$`, `£`, `€`, `¥`, or `₹`. ISO currency codes remain internal so historical transactions can stay normalized and currencies are never silently converted or combined.

The app derives from `lrodeveloperr/Ios-shell`; the reusable shell repository remains unchanged.

No hosted build or TestFlight workflow runs automatically. Production packaging requires the publisher-owned AdMob application/banner IDs and the matching App Store Connect monthly product.
