# Welding Gas Wallet — iOS

Native Swift 6 and SwiftUI implementation of the approved Welding Gas Wallet MVP for iPhone and iPad. Flutter is not used.

The app is an offline, cylinder-only wallet with search and status filters, refill/exchange/cost history, suppliers, reminders, duplicate entry, reversible deletion, archive/return, native backup files, fully localized English and Latin American Spanish, automatic-region currency with manual override, a three-active-cylinder free limit, and an annual StoreKit subscription that unlocks unlimited active cylinders. Additional languages remain hidden until their complete product catalog passes cultural review. The app contains no advertising SDK, banner, consent flow, or device-location pricing logic. App Store Connect owns the US$19.99 annual base price and geographic storefront pricing, and customer-facing price, currency, and billing-period text always comes from StoreKit.

Currency values are shown with locale-appropriate signs such as `$`, `£`, `€`, `¥`, or `₹`. ISO currency codes remain internal so historical transactions can stay normalized and currencies are never silently converted or combined.

The app derives from `lrodeveloperr/Ios-shell`; the reusable shell repository remains unchanged.

No hosted build or TestFlight workflow runs automatically. Production packaging requires `com.gooduse.weldinggaswallet.pro.yearly` in App Store Connect, configured for one year with a US$19.99 United States base price and reviewed storefront prices for every enabled region. The app never derives prices from device location.
