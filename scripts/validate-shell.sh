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

for path in project.yml README.md Shell/App/WeldingGasWalletApp.swift Shell/App/ShellConfiguration.swift Shell/App/ShellRootView.swift Shell/Features/FeatureView.swift Shell/Features/WalletStore.swift Shell/Features/SettingsView.swift Shell/Services/PurchaseService.swift Shell/Services/AdConsentService.swift Shell/Services/AdaptiveAdBanner.swift Shell/Resources/Info-Ads.plist Shell/Resources/PrivacyInfo.xcprivacy; do
  require_file "$path"
done

reject_tree_text 'import (Flutter|React|ReactNative)|FlutterViewController|RCTRootView' Shell
require_text project.yml 'name: WeldingGasWallet'
require_text project.yml 'PRODUCT_BUNDLE_IDENTIFIER: com.goodusestudios.weldinggaswallet'
require_text project.yml 'SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) ADS_ENABLED"'
require_text Shell/App/ShellConfiguration.swift 'mode: .adsWithSubscription'
require_text Shell/App/ShellConfiguration.swift 'com.gooduse.weldinggaswallet.pro.monthly'
require_text Shell/App/ShellConfiguration.swift 'BackupConfiguration(enabled: true)'
require_text Shell/App/ShellRootView.swift 'Color.clear.frame(height: 60)'
require_text Shell/Features/FeatureView.swift 'activeCylinders.count >= 3'
require_text Shell/Features/FeatureView.swift 'Duplicate cylinder'
require_text Shell/Features/FeatureView.swift 'Search cylinders'
require_text Shell/Features/WalletStore.swift 'func currencySign(for code: String)'
require_text Shell/Features/WalletStore.swift 'func deleteAllData()'
require_text Shell/Features/WalletStore.swift 'try? await Task.sleep(for: .seconds(15))'
require_text Shell/Features/SettingsView.swift 'Type DELETE'
require_text Shell/Features/SettingsView.swift 'wallet.currencySign(for:'
require_text Shell/Services/AdConsentService.swift 'ConsentForm.loadAndPresentIfRequired'
require_text Shell/Services/PurchaseService.swift 'Transaction.currentEntitlements'

language_count="$(sed -n '/static let supportedLanguages:/,/^    ]/p' Shell/App/ShellConfiguration.swift | grep -c '\.init(id:')"
[[ "$language_count" == "30" ]] || fail "Expected 30 language choices; found $language_count"
! grep -Fq '.init(id: "system"' Shell/App/ShellConfiguration.swift || fail 'Language selector must not contain Follow system'

for workflow in .github/workflows/*.yml; do
  require_text "$workflow" 'workflow_dispatch:'
  if rg -n '^\s+(push|pull_request|schedule):' "$workflow"; then fail "$workflow must remain manual-only"; fi
done

if command -v plutil >/dev/null 2>&1; then
  plutil -lint Shell/Resources/Info-Ads.plist >/dev/null
  plutil -lint Shell/Resources/PrivacyInfo.xcprivacy >/dev/null
fi

if [[ "$mode" == "--release" ]]; then
  reject_tree_text 'MISSING_PRODUCTION_ADMOB' Shell/Resources
fi

echo "Welding Gas Wallet iOS validation passed ($mode)."
