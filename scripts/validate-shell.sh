#!/usr/bin/env bash
set -euo pipefail

mode="${1:---app}"
case "$mode" in
  --app|--release) ;;
  *) echo "Usage: $0 [--app|--release]" >&2; exit 64 ;;
esac

fail() { echo "VALIDATION FAILED: $*" >&2; exit 1; }
require_file() { [[ -f "$1" ]] || fail "Missing $1"; }
require_text() { grep -Fq "$2" "$1" || fail "$1 must contain: $2"; }
search_tree() {
  if command -v rg >/dev/null 2>&1; then
    rg -n -- "$1" "$2"
  else
    grep -REn -- "$1" "$2"
  fi
}
reject_tree_text() { ! search_tree "$1" "$2" || fail "Forbidden implementation detected: $1"; }

[[ "$(git ls-files -s scripts/validate-shell.sh | awk '{print $1}')" == "100755" ]] || fail "scripts/validate-shell.sh must retain its executable bit"

for path in project.yml README.md Shell/App/WeldingGasWalletApp.swift Shell/App/ShellConfiguration.swift Shell/App/ShellRootView.swift Shell/Features/FeatureView.swift Shell/Features/WalletStore.swift Shell/Features/SettingsView.swift Shell/Features/PaywallView.swift Shell/Services/PurchaseService.swift Shell/Resources/Info.plist Shell/Resources/PrivacyInfo.xcprivacy Shell/Resources/Assets.xcassets/CylinderTabIcon.imageset/Contents.json Shell/Resources/Assets.xcassets/CylinderTabIcon.imageset/CylinderTabIcon.svg; do
  require_file "$path"
done

reject_tree_text 'import (Flutter|React|ReactNative)|FlutterViewController|RCTRootView' Shell
require_text project.yml 'name: WeldingGasWallet'
require_text project.yml 'PRODUCT_BUNDLE_IDENTIFIER: com.goodusestudios.weldinggaswallet'
require_text project.yml 'INFOPLIST_FILE: Shell/Resources/Info.plist'
require_text Shell/App/ShellConfiguration.swift 'mode: .freemiumWithSubscription'
require_text Shell/App/ShellConfiguration.swift 'com.gooduse.weldinggaswallet.pro.yearly'
require_text Shell/App/ShellConfiguration.swift 'BackupConfiguration(enabled: true)'
require_text Shell/App/ShellRootView.swift 'Image("CylinderTabIcon")'
require_text Shell/App/ShellRootView.swift 'localizedDestinationTitle(destination)'
require_text Shell/App/ShellRootView.swift 'SettingsView(model: model, wallet: wallet)'
require_text Shell/App/ShellRootView.swift '.environment(model)'
! grep -Fq 'OnboardingView(' Shell/App/ShellRootView.swift || fail 'Production launch must not gate the wallet behind onboarding'
! grep -Fq 'legalConsent' Shell/App/ShellRootView.swift || fail 'Production launch must not depend on persisted legal acceptance'
require_text Shell/Features/SettingsView.swift 'legalButton(.privacy'
require_text Shell/Features/SettingsView.swift 'legalButton(.terms'
require_text Shell/Features/PaywallView.swift 'Button("privacy")'
require_text Shell/Features/PaywallView.swift 'Button("terms")'
require_text Shell/Features/WalletStore.swift 'static let freeActiveCylinderLimit = 3'
require_text Shell/Features/WalletStore.swift 'func canAddCylinder(isEntitled: Bool)'
require_text Shell/Features/WalletStore.swift 'func canManageCylinder(_ id: UUID, isEntitled: Bool)'
require_text Shell/Features/WalletStore.swift 'func requiresFreeCylinderSelection(isEntitled: Bool)'
require_text Shell/Features/WalletStore.swift 'func selectFreeManagedCylinders(_ ids: Set<UUID>, isEntitled: Bool)'
require_text Shell/Features/FeatureView.swift 'Duplicate cylinder'
require_text Shell/Features/FeatureView.swift 'Search cylinders'
require_text Shell/Features/WalletStore.swift 'func currencySign(for code: String)'
require_text Shell/Features/WalletStore.swift 'Locale.commonISOCurrencyCodes'
require_text Shell/Features/WalletStore.swift 'selectableCurrencyCodes'
require_text Shell/Features/WalletStore.swift 'func deleteAllData()'
require_text Shell/Features/WalletStore.swift 'try? await Task.sleep(for: .seconds(15))'
require_text Shell/Features/SettingsView.swift 'delete.confirmationWord'
require_text Shell/Features/SettingsView.swift 'wallet.currencySign(for:'
require_text Shell/Services/PurchaseService.swift 'Transaction.currentEntitlements'
require_text Shell/Resources/Info.plist 'ITSAppUsesNonExemptEncryption'
require_text Shell/Features/PaywallView.swift 'paywall.benefit.readiness'
require_text Shell/Features/PaywallView.swift 'paywall.benefit.history'
require_text Shell/Features/PaywallView.swift 'purchases.retryProducts()'
require_text Shell/Features/PaywallView.swift 'purchase.productUnavailable'
require_text Shell/Features/SettingsView.swift 'settings.upgrade.price.period %@ %@'
require_text Shell/Features/SettingsView.swift 'BackupView(wallet: wallet, isEntitled:'
require_text Shell/Features/SettingsView.swift 'SubscriptionSettingsPresentation.resolve'
require_text Shell/Features/SettingsView.swift 'shell.settings.subscription.manage'
require_text Shell/Features/SettingsView.swift '.appNavigationTitle("settings")'
require_text Shell/App/AppLocalizedNavigationTitle.swift 'Text(verbatim: AppLocalization.string(key, locale: language.locale))'
require_text Shell/Features/SettingsView.swift '.buttonStyle(.plain)'
require_text Shell/Services/PurchaseService.swift 'case subscribed(willAutoRenew: Bool, expirationDate: Date)'
require_text Shell/Services/PurchaseService.swift 'case gracePeriod(expirationDate: Date)'
require_text Shell/Services/PurchaseService.swift 'case billingRetry'
require_text Shell/Services/PurchaseService.swift 'scheduleEntitlementRefresh(at:'
reject_tree_text 'Make the useful thing unlimited|Clear value, transparent App Store pricing|Unlimited core actions|Version information and app-specific notices belong here' Shell
require_text .github/workflows/testflight.yml 'UPLOAD WELDING WALLET PRODUCTION TEST'
require_text .github/workflows/testflight.yml 'Run unit tests before upload'
require_text .github/workflows/testflight.yml 'ENABLE_TESTABILITY=YES'
require_text .github/workflows/testflight.yml 'date -u +%y%m%d%H%M'
! grep -Fq 'SCREENSHOT_BUILD' .github/workflows/testflight.yml || fail 'Production TestFlight workflow must not compile SCREENSHOT_BUILD'

for path in project.yml Shell; do
  reject_tree_text 'GoogleMobileAds|UserMessagingPlatform|GADApplicationIdentifier|WeldingAdBannerUnitID|ADS_ENABLED|WELDING_IOS_ADMOB|ca-app-pub-' "$path"
done

for url in privacy terms support deletion disclaimer; do
  require_text Shell/App/ShellConfiguration.swift "https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/$url/"
done

language_count="$(sed -n '/static let supportedLanguages:/,/^    ]/p' Shell/App/ShellConfiguration.swift | grep -c '\.init(id:')"
[[ "$language_count" == "31" ]] || fail "Expected the complete 31-language product catalog; found $language_count"
! grep -Fq '.init(id: "system"' Shell/App/ShellConfiguration.swift || fail 'Language selector must not contain Follow system'
require_text Shell/App/ShellRootView.swift '.environment(\.layoutDirection, model.language.layoutDirection)'
require_text Shell/Services/LanguageController.swift '["ar", "he", "ur"]'
python3 scripts/validate-localizations.py

for workflow in .github/workflows/*.yml; do
  require_text "$workflow" 'workflow_dispatch:'
  if search_tree '^[[:space:]]+(push|pull_request|schedule):' "$workflow"; then fail "$workflow must remain manual-only"; fi
done

if command -v plutil >/dev/null 2>&1; then
  plutil -lint Shell/Resources/Info.plist >/dev/null
  plutil -lint Shell/Resources/PrivacyInfo.xcprivacy >/dev/null
fi

echo "Welding Gas Wallet iOS validation passed ($mode)."
