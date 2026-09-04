#!/usr/bin/env bash
set -euo pipefail

fail() { echo "COMMERCE BRANDING CHECK FAILED: $*" >&2; exit 1; }

commerce_files=()
while IFS= read -r path; do commerce_files+=("$path"); done < <(
  find Shell -type f -name '*.swift' \
    \( -iname '*paywall*' -o -iname '*purchase*' -o -iname '*subscription*' \
       -o -iname '*winback*' -o -iname '*restore*' -o -iname '*commerce*' \
       -o -iname '*upgrade*' -o -iname '*offer*' \) | sort
)

(( ${#commerce_files[@]} > 0 )) || fail "No commerce surfaces were found"

# SF Symbols are allowed. Named image assets and app-brand references are not.
if command -v rg >/dev/null 2>&1; then
  matches_named_image() {
    rg -n -P 'Image\s*\(\s*(?!systemName:)|UIImage\s*\(\s*named:|ImageResource\.|ShellConfiguration\.appName|\.appIcon\b|Asset\.[A-Za-z0-9_]*(Logo|Icon|Brand)' "${commerce_files[@]}"
  }
else
  matches_named_image() {
    perl -ne '
      BEGIN { $found = 0 }
      if (/Image\s*\(\s*(?!systemName:)|UIImage\s*\(\s*named:|ImageResource\.|ShellConfiguration\.appName|\.appIcon\b|Asset\.[A-Za-z0-9_]*(Logo|Icon|Brand)/) {
        print "$ARGV:$.:$_";
        $found = 1;
      }
      END { exit($found ? 0 : 1) }
    ' "${commerce_files[@]}"
  }
fi

if matches_named_image; then
  fail "A commerce surface references an app image, icon, logo, name, or brand asset"
fi

echo "Commerce surfaces contain no app logo/icon/brand asset references."
