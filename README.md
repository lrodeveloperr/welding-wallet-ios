# Welding Gas Wallet — iOS

Native Swift 6 and SwiftUI implementation of the approved Welding Gas Wallet MVP for iPhone and iPad. Flutter is not used.

The app is an offline, cylinder-only wallet with search and status filters, refill/exchange/cost history, suppliers, reminders, duplicate entry, reversible deletion, archive/return, native backup files, fully localized English and Latin American Spanish, automatic-region currency with manual override, a three-active-cylinder free limit, an anchored lower ad banner, and a monthly StoreKit subscription that removes the banner and limit. Additional languages remain hidden until their complete product catalog passes cultural review. The subscription uses a US$1.99 monthly reference price with geo-priced territory equivalents; the customer-facing price is always supplied by StoreKit.

Currency values are shown with locale-appropriate signs such as `$`, `£`, `€`, `¥`, or `₹`. ISO currency codes remain internal so historical transactions can stay normalized and currencies are never silently converted or combined.

The app derives from `lrodeveloperr/Ios-shell`; the reusable shell repository remains unchanged.

No hosted build or TestFlight workflow runs automatically. Production packaging requires the publisher-owned AdMob application/banner IDs and the matching App Store Connect monthly product configured for one month, a US$1.99 reference price, and geo-priced territory equivalents.
