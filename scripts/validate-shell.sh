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
reject_tree_text() { ! rg -n "$1" "$2" || fail "Forbidden implementation detected: $1"; }

[[ -x scripts/validate-shell.sh ]] || fail "scripts/validate-shell.sh must retain its executable bit"

for path in project.yml README.md Shell/App/WeldingGasWalletApp.swift Shell/App/ShellConfiguration.swift Shell/App/ShellRootView.swift Shell/Features/FeatureView.swift Shell/Features/WalletStore.swift Shell/Features/SettingsView.swift Shell/Features/PaywallView.swift Shell/Services/PurchaseService.swift Shell/Resources/Info.plist Shell/Resources/PrivacyInfo.xcprivacy Shell/Resources/Assets.xcassets/CylinderTabIcon.imageset/Contents.json Shell/Resources/Assets.xcassets/CylinderTabIcon.imageset/CylinderTabIcon.svg; do
  require_file "$path"
done

reject_tree_text 'import (Flutter|React|ReactNative)|FlutterViewController|RCTRootView' Shell
require_text project.yml 'name: WeldingGasWallet'
require_text project.yml 'PRODUCT_BUNDLE_IDENTIFIER: com.goodusestudios.weldinggaswallet'
require_text project.yml 'INFOPLIST_FILE: Shell/Resources/Info.plist'
require_text Shell/App/ShellConfiguration.swift 'mode: .freemiumWithSubscription'
require_text Shell/App/ShellConfiguration.swift 'com.gooduse.weldinggaswallet.pro.monthly'
require_text Shell/App/ShellConfiguration.swift 'BackupConfiguration(enabled: true)'
require_text Shell/App/ShellRootView.swift 'Label("Cylinders", image: "CylinderTabIcon")'
require_text Shell/App/ShellRootView.swift 'SettingsView(model: model, wallet: wallet)'
require_text Shell/App/ShellRootView.swift '.environment(model)'
require_text Shell/Features/WalletStore.swift 'static let freeActiveCylinderLimit = 3'
require_text Shell/Features/WalletStore.swift 'func canAddCylinder(isEntitled: Bool)'
require_text Shell/Features/WalletStore.swift 'func canManageCylinder(_ id: UUID, isEntitled: Bool)'
require_text Shell/Features/WalletStore.swift 'func requiresFreeCylinderSelection(isEntitled: Bool)'
require_text Shell/Features/WalletStore.swift 'func selectFreeManagedCylinders(_ ids: Set<UUID>, isEntitled: Bool)'
require_text Shell/Features/FeatureView.swift 'Duplicate cylinder'
require_text Shell/Features/FeatureView.swift 'Search cylinders'
require_text Shell/Features/WalletStore.swift 'func currencySign(for code: String)'
require_text Shell/Features/WalletStore.swift 'func deleteAllData()'
require_text Shell/Features/WalletStore.swift 'try? await Task.sleep(for: .seconds(15))'
require_text Shell/Features/SettingsView.swift 'delete.confirmationWord'
require_text Shell/Features/SettingsView.swift 'wallet.currencySign(for:'
require_text Shell/Services/PurchaseService.swift 'Transaction.currentEntitlements'
require_text Shell/Resources/Info.plist 'ITSAppUsesNonExemptEncryption'
require_text Shell/Features/PaywallView.swift 'paywall.benefit.readiness'
require_text Shell/Features/PaywallView.swift 'paywall.benefit.history'
require_text Shell/Features/SettingsView.swift 'settings.upgrade.price.period %@ %@'
require_text Shell/Features/SettingsView.swift 'BackupView(wallet: wallet, isEntitled:'
require_text Shell/Services/PurchaseService.swift 'case subscribed(willAutoRenew: Bool, expirationDate: Date)'
require_text Shell/Services/PurchaseService.swift 'case gracePeriod(expirationDate: Date)'
require_text Shell/Services/PurchaseService.swift 'case billingRetry'
require_text Shell/Services/PurchaseService.swift 'scheduleEntitlementRefresh(at:'
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
[[ "$language_count" == "2" ]] || fail "Expected only the two completed language choices; found $language_count"
! grep -Fq '.init(id: "system"' Shell/App/ShellConfiguration.swift || fail 'Language selector must not contain Follow system'

for locale in en es-419; do
  require_file "Shell/Resources/$locale.lproj/Localizable.strings"
done
python3 scripts/validate-localizations.py

for workflow in .github/workflows/*.yml; do
  require_text "$workflow" 'workflow_dispatch:'
  if rg -n '^\s+(push|pull_request|schedule):' "$workflow"; then fail "$workflow must remain manual-only"; fi
done

if command -v plutil >/dev/null 2>&1; then
  plutil -lint Shell/Resources/Info.plist >/dev/null
  plutil -lint Shell/Resources/PrivacyInfo.xcprivacy >/dev/null
fi

echo "Welding Gas Wallet iOS validation passed ($mode)."
