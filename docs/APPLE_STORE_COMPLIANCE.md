# Apple App Store compliance gate

Reviewed against Apple’s official material on **2026-09-03**. Apple’s App Review Guidelines showed “Last Updated: June 8, 2026” when reviewed. Policy changes and app-specific behavior mean a template can reduce risk but cannot guarantee acceptance. Before every submission, a human or reviewing agent must open the current sources below, assess every row, and record **PASS**, **N/A with reason**, or **BLOCKED**.

## Official sources

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/)
- [Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)
- [In-app purchase design guidance](https://developer.apple.com/design/human-interface-guidelines/in-app-purchase)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [Required-reason API declarations](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Creating your product page](https://developer.apple.com/app-store/product-page/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Preparing for App Review](https://developer.apple.com/distribute/app-review/)
- [Set up win-back offers](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-win-back-offers/)

## Mandatory shell checks

- [ ] Native SwiftUI experience is complete, stable, responsive and useful; no crashes, broken links, placeholders, demo copy or inaccessible features.
- [ ] App identity, screenshots, previews, description, privacy answers, age rating, category and review notes match the binary and current business model.
- [ ] App Review can reach every feature. Provide a demo account, sample data, QR code, hardware instructions or fully featured demo mode when applicable.
- [ ] Privacy Policy and Terms of Use links use HTTPS, open before purchase and onboarding acceptance, and match actual data handling.
- [ ] Privacy manifest, Required Reason APIs, SDK manifests/signatures and App Store privacy answers match the final archive—not the template plan.
- [ ] `UserDefaults` access remains declared as `NSPrivacyAccessedAPICategoryUserDefaults` with the app-only `CA92.1` reason; reassess if data becomes accessible outside the app or a new required-reason API is added.
- [ ] The app asks only for permissions needed at that moment, explains them clearly and remains useful when optional permission is declined.
- [ ] No private API, downloaded executable code, misleading capability, hidden feature, placeholder or dormant switch ships.
- [ ] Accessibility, Dynamic Type, VoiceOver, contrast, 44-point hit targets, RTL, compact iPhone and iPad layouts were manually checked using `UI_REGRESSION_MATRIX.md`.

## Product-page listing

- [ ] The first three screenshots tell the core search-results story: know what is ready, see refill/cost history, and keep cylinder/supplier details together. Every later screenshot communicates one distinct benefit.
- [ ] Screenshots show real app UI, contain no alpha channel, meet a current accepted size, and include the required 13-inch set because this binary supports iPad.
- [ ] English and Latin American Spanish each have metadata and screenshots whose visible UI matches that language; no translated overlay is placed over an English interface.
- [ ] The description opens with the clearest differentiator, uses a short feature list and welding terminology, and omits a fixed subscription price because storefront prices vary.
- [ ] Name and subtitle fit their 30-character limits; promotional text fits 170 characters; keywords fit 100 characters and exclude duplicates, category/app terms, competitor names and unauthorized trademarks.
- [ ] The privacy label and URLs match the final SDK inventory. Review notes give exact steps to the three-cylinder limit, paywall, Restore Purchases and Manage Subscription.

### Current listing blocker found 2026-09-03

The five configured HTTPS pages are live and product-specific, but the published Privacy Policy, Terms, and Support text still describes AdMob/UMP, ad resumption, and rejection of free restores containing more than three active cylinders. The current iOS binary contains no advertising stack and now preserves valid paid-era backups while applying a read-only excess-record policy. Update and republish those three documents, including any advertising-based territory restriction language, before marking legal/store parity as passed. The policy source is not part of this repository, so this code change does not alter the live pages.

## Purchases and subscriptions

- [ ] Digital features/content use StoreKit In-App Purchase unless a current guideline exception applies and is documented.
- [ ] Before confirmation, the commerce surface clearly states the exact benefit, StoreKit-fetched localized price and billing period. Do not hard-code a storefront price.
- [ ] `com.gooduse.weldinggaswallet.pro.yearly` is configured for one year at a US$19.99 United States base price. App Store Connect supplies reviewed geographic storefront prices; repository code has no device-location pricing rules and displays StoreKit's localized price, currency, and period.
- [ ] Auto-renewal is disclosed; privacy and Terms of Use are visible; subscription grouping prevents accidental duplicate subscriptions.
- [ ] Restore is visible for restorable purchases. Pending, cancelled, unverified, expired, refunded or revoked transactions never unlock access.
- [ ] Cancelling auto-renewal retains access through verified paid expiration. Verified Billing Grace Period remains entitled; billing retry after grace, expiry and revocation do not.
- [ ] Purchase success is verified through StoreKit; `Transaction.updates` and current entitlements keep access current.
- [ ] Free trial, introductory, promotional, offer-code and win-back claims appear only when StoreKit confirms eligibility and terms.
- [ ] Recurring payment has defensible ongoing value. One-time value is not misleadingly sold as a subscription.
- [ ] App description and screenshots identify paid features when required by Guideline 2.3.2.
- [ ] Product display name, description, review screenshot and localization in App Store Connect are accurate and appropriate for all audiences.
- [ ] If promoting an IAP or win-back offer, its promotional image is **not the app icon and not an app screenshot**, per Apple’s win-back guidance.
- [ ] House rule: in-app paywall, purchase, restore, subscription and win-back surfaces contain no app logo, AppIcon, custom brand mark or app-name hero. Run `scripts/check-commerce-branding.sh`. This is intentionally stricter than Apple’s published in-app UI rule and prevents recurrence of the prior rejection pattern.
- [ ] Standard Apple EULA link appears in the description when used, or the custom EULA is configured in App Store Connect.

## Subscription-only profile

- [ ] Archive `WeldingGasWallet` and confirm it has no GoogleMobileAds/UMP framework, GAD/SKAdNetwork metadata, ad unit IDs, consent controls, or reserved banner spacing.
- [ ] Free users can use the complete wallet with no more than three active cylinders; a verified annual entitlement removes only that cylinder limit.
- [ ] Settings, backup restore, duplicate/add actions, and the paywall all apply the same three-active-cylinder rule.

## Full App Review Guidelines applicability sweep

The shell cannot decide product content. Review every numbered section in the current official guidelines, including subsections, and attach evidence or an N/A reason:

| Guideline family | Required product-level decision |
|---|---|
| 1 Safety | Objectionable content; user-generated/creator content moderation; children; physical harm; developer information |
| 2 Performance | Completeness; beta/demo behavior; accurate metadata; hardware compatibility; software requirements |
| 3 Business | Payments; subscriptions; other purchase methods; advertising; enterprise/person-to-person/service-specific models |
| 4 Design | Copycats; minimum functionality; spam; extensions; Apple sites/services; alternate icons; Sign in with Apple |
| 5 Legal | Privacy; data use/sharing; permissions; regulated fields; intellectual property; gambling; VPN/MDM; developer conduct |

Do not mark a family N/A as a whole. Review its current subsections. Examples that commonly become applicable only after product code is added include accounts and account deletion, social login, health/medical claims, financial services, location, background activity, UGC moderation, kids, contests, crypto, VPN, MDM, government sources and third-party trademarks.

## Submission evidence record

- App/version/build:
- Shell contract version:
- Review date and guideline “Last Updated” date:
- Monetization mode and App Store product IDs:
- Archive target (`WeldingGasWallet`):
- Data collected/tracked and SDK inventory:
- Legal document versions/URLs:
- Review access/sample data supplied:
- App-specific guideline exceptions or N/A reasons:
- Reviewer and final result:
