# Welding Gas Wallet — Internal Store Listing Package

> Internal submission worksheet. Do not publish through GitHub Pages or link from customer-facing legal pages.

This page records the code-grounded English listing and disclosure baseline for the final no-advertising model approved on 3 September 2026. The controlling iOS source was verified at commit `e052d8ae0f45a801d769cdb944c45565b66cbadb`. Android follows the same structure and data-flow model. Store forms must be reconciled with each final signed binary before submission.

## App Store

**Name:** Welding Gas Wallet

**Subtitle:** Cylinder inventory & reminders

**Promotional text:** Know which welding-gas cylinders you have, what they cost and what needs attention next—with quick status updates, optional reminders and local-first records.

**Keywords:** welding,gas,cylinder,bottle,inventory,refill,rental,oxygen,argon,acetylene,reminder,cost

### Description

Keep your welding-gas cylinders organised without spreadsheets or an account.

Welding Gas Wallet gives you one clear place to:

- Record gas type, capacity, serial number, supplier and ownership
- Mark a cylinder Ready, Low, Empty or Away with one tap
- Log refills, exchanges, rental or lease costs, deposits and notes
- Review a simple activity history
- Set optional local reminders for refills, payments, returns and checks
- Back up and restore through the system file picker

Your core records stay on your device unless you export a backup. The app does not display ads, scan cylinders, use the camera, read tank pressure or make safety or compliance decisions.

Free includes up to three active cylinders. An auto-renewing monthly Pro subscription unlocks unlimited active cylinders. The approved commercial base price is US$1.99 per month. The App Store purchase sheet shows the authoritative displayed price, currency, taxes, renewal date and any eligible offer before confirmation. Cancel in App Store subscription settings.

Terms: https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/terms/

## Google Play

**App name:** Welding Gas Wallet

**Short description:** Track welding-gas cylinders, refill costs, suppliers and reminders locally.

### Full description

Keep your welding-gas cylinders organised without spreadsheets or an account.

Welding Gas Wallet is a local-first inventory for the cylinders you own, rent, lease or hold on deposit.

- Record gas type, capacity, serial number, supplier and ownership
- Mark a cylinder Ready, Low, Empty or Away with one tap
- Log refills, exchanges, rental or lease costs, deposits and notes
- Review a simple activity history
- Set optional local reminders for refills, payments, returns and checks
- Back up and restore through the system file picker

Your core records stay on your device unless you export a backup. The app does not display ads, scan cylinders, use the camera, read tank pressure or make safety or compliance decisions.

Free includes up to three active cylinders. An auto-renewing monthly Pro subscription unlocks unlimited active cylinders. The approved commercial base price is US$1.99 per month. Google Play shows the authoritative displayed price, currency, taxes, renewal date and any eligible offer before purchase. Manage or cancel the subscription in Google Play.

## Reviewer notes

### Apple App Review information

1. **Function and audience:** Welding Gas Wallet is a local-first cylinder inventory for adult welders, fabricators, workshop operators and people who own, rent or exchange welding-gas cylinders. It replaces scattered notes with status, supplier, cost, history and reminder records. It does not measure gas, scan a cylinder or provide safety or compliance decisions.
2. **Access:** No login, mandatory legal onboarding, demo account, external hardware or sample file is required. The app opens directly to its core functions. Add a cylinder manually, use the status buttons, record a refill or exchange, then open Settings for reminders, backup and restore, deletion, legal links and purchases.
3. **Free limit:** A free user may keep up to three active cylinders. Attempting to add or duplicate a fourth active cylinder opens the upgrade screen. The app contains no advertising.
4. **Subscription:** Settings → Upgrade, or the fourth-cylinder gate, presents the monthly product `com.gooduse.weldinggaswallet.pro.monthly`. Configure it as a one-month subscription with the approved US$1.99 base price. The app applies no geographic-pricing rules; the customer-facing price, currency and period are supplied by StoreKit. An active subscription unlocks unlimited active cylinders. Restore purchases and subscription management are visible, and Privacy Policy and Terms links are available in the app.
5. **External services:** StoreKit provides iOS purchases; Google Play Billing provides Android purchases; operating-system notifications provide local reminders; and user-selected file providers receive backup files. The final model has no advertising, advertising-consent, analytics, attribution, tracking, backend, AI or third-party crash-reporting service.
6. **Release target:** Submit the normal production target. The Android and iOS releases contain no advertising SDK, consent SDK, advertising identifier declaration, ad-network attribution entry, banner UI, test-ad configuration or placeholder advertising identifier. Do not submit a debug, screenshot or test monetization build.
7. **Regions:** Enable every App Store and Google Play country or region the store permits GoodUse Studios to enable. There are no voluntary country exclusions. Store availability, prices, taxes, eligible offers, default currency and measurement-unit suggestions can still vary under store and device rules.
8. **Regulated material:** The app is a user-entered personal inventory and does not provide welding certification, engineering, inspection, compressed-gas compliance or regulated safety decisions. It contains no third-party standards text, certification marks or protected training content.
9. **Backup restore:** Android and iOS accept supported, internally consistent JSON backups up to 5 MB. A free user may restore more than three active cylinders, but must select up to three to manage. Other active cylinders remain visible and read-only and may be exported, returned, archived or deleted until Pro becomes active. A rejected restore leaves the current wallet unchanged. Backup files never contain Pro entitlement.
10. **Languages:** The current iOS release enables English and Latin American Spanish. The published legal documents are in English, and the app identifies that language on its legal-document settings rows. Do not advertise or enable additional app locales until their full product catalog passes the release gate.

## Store declarations

- **Contains ads:** No on Android and iOS.
- **Subscription:** One auto-renewing monthly Pro product on each platform; product identifier `com.gooduse.weldinggaswallet.pro.monthly`.
- **Pricing:** One month; approved US$1.99 commercial base price. The app contains no geographic-pricing logic and must display the applicable store's localized price and currency.
- **Pro benefit:** Unlimited active cylinders while entitlement is active.
- **Advertising identifiers and tracking:** No advertising ID access, no IDFA use, no App Tracking Transparency prompt and no cross-app tracking in the final signed binaries.
- **Account creation:** No.
- **Camera:** Not used or requested.
- **Core record collection by GoodUse Studios:** No; cylinder records remain local unless the user selects a backup destination.
- **Analytics and third-party SDK processing:** No advertising, consent-management, analytics, attribution or third-party crash-reporting SDK in the final model.
- **Notifications:** Optional local notifications, requested only when the user enables an alert.
- **Audience:** Adults 18 and over; not directed to children and not in a kids or families category.
- **Availability:** All countries and regions that the applicable store permits GoodUse Studios to enable; no voluntary exclusions.

## Worldwide availability checklist

- Select every available country or region in App Store Connect and Google Play Console, subject to any store-specific eligibility or local-compliance prompts.
- Complete and verify the App Store Connect Digital Services Act trader assessment and required public contact details for European Union distribution.
- Complete any local compliance, licensing or business-information fields requested by a store for particular countries or regions. Do not claim availability where the store blocks distribution until a required field is satisfied.
- Reconcile subscription availability and the localized store price in every enabled storefront.

### Google Play Data safety baseline

For the no-advertising Android app, the expected initial answer is that the app does not collect or share a required user-data type. The app has no advertising, analytics, attribution, remote backend or third-party crash-reporting SDK and no other network data flow beyond Google Play Billing.

- **Core cylinder records, reminders and backup contents:** Processed on the device. A user-selected backup destination is a user-initiated transfer and is described in the Privacy Policy.
- **Purchase data:** Google Play processes payment and account data as the independent store provider. Reconcile any information actually transmitted by the final Billing implementation against Google's then-current Data safety definitions.
- **Account deletion:** Not applicable because the app has no account creation.
- **Local deletion:** **Settings → Delete all data** removes cylinders, suppliers, costs, activity, reminders and wallet preferences after confirmation. It does not reset the selected language, clear locally cached store-entitlement evidence, cancel a subscription, or delete provider-controlled records, separately exported backups or limited accounting records that GoodUse Studios must retain.
- **Data encrypted in transit:** Answer according to the final bundle's actual network traffic. Do not use a former advertising-SDK answer.
- **Ads and Advertising ID:** No.

### App Store privacy baseline

The expected App Store privacy answer is **Data Not Collected** if the final signed archive continues to match the verified source: core records are processed only on the device, user backups are sent only to a destination the user selects, and the app contains no third-party data-collecting SDK. Apple's own StoreKit processing is not treated as developer collection merely because the app uses StoreKit. Optional, infrequent support contact initiated by the user may qualify for Apple's optional-disclosure exception, but it remains disclosed in the Privacy Policy.

- **User-entered cylinder records:** Stored locally and transferred only when the user selects a backup destination; not collected by GoodUse Studios.
- **Tracking:** No. The iOS privacy manifest declares `NSPrivacyTracking` as false, and the app does not request ATT or use IDFA.
- **Required-reason APIs:** The manifest declares the UserDefaults required-reason API category for app preferences. Reconcile the final archive privacy report before submission.
- **Final control:** If the signed archive, privacy report or network inspection reveals any additional collection, update App Store Connect and this policy before release.

### Additional Play declarations

- **App access:** All core free functionality is available without login; no credentials or access instructions are required.
- **Ads:** Contains ads — No.
- **Advertising ID:** No; remove any advertising-ID permission or SDK access from the final bundle.
- **Target audience:** Adults 18 and over. Do not select child age groups or the Designed for Families program.
- **Content rating:** Utility or inventory; no violence, sexual content, gambling, controlled-substance sales, user communication or public user-generated content.
- **Special categories:** Not a health, medical, finance, government, news, election, dating or social app.
- **Permissions:** Internet access supports store billing. Notification and boot-completed handling may support optional local reminders. Camera, microphone, contacts, precise location, advertising ID and broad photo or video access are not requested in the final model.

[Privacy Policy](https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/privacy/) · [Terms](https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/terms/) · [Support](https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/support/)
