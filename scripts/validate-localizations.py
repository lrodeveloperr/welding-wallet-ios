#!/usr/bin/env python3
"""Release gate: exposed locales must be complete and catalog keys must match."""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "Shell/App/ShellConfiguration.swift"
CATALOG_ROOT = ROOT / "Shell/Resources"

locales = re.findall(r'\.init\(id: "([^"]+)", displayName:', CONFIG.read_text())

def keys(path: Path) -> set[str]:
    return set(re.findall(r'^\s*"((?:\\.|[^"])*)"\s*=', path.read_text(), re.MULTILINE))

english = CATALOG_ROOT / "en.lproj/Localizable.strings"
if not english.is_file():
    sys.exit("LOCALIZATION FAILED: missing English source catalog")
source = keys(english)

for locale in locales:
    path = CATALOG_ROOT / f"{locale}.lproj/Localizable.strings"
    if not path.is_file():
        sys.exit(f"LOCALIZATION FAILED: enabled locale {locale} has no catalog")
    current = keys(path)
    missing = sorted(source - current)
    extra = sorted(current - source)
    if missing or extra:
        sys.exit(
            f"LOCALIZATION FAILED: {locale} key mismatch; "
            f"missing={missing[:8]} extra={extra[:8]}"
        )

ui_files = [
    ROOT / "Shell/Features/FeatureView.swift",
    ROOT / "Shell/Features/SettingsView.swift",
    ROOT / "Shell/Features/PaywallView.swift",
    ROOT / "Shell/App/ShellRootView.swift",
]
ui_pattern = re.compile(
    r'(?:Text|Button|Section|TextField|Toggle|Menu|ContentUnavailableView|navigationTitle)\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'
)
uncatalogued: list[str] = []
for ui_file in ui_files:
    for key in ui_pattern.findall(ui_file.read_text()):
        if "\\(" not in key and key not in source:
            uncatalogued.append(f"{ui_file.relative_to(ROOT)}: {key}")
if uncatalogued:
    sys.exit("LOCALIZATION FAILED: uncatalogued UI literals: " + "; ".join(uncatalogued[:12]))

print(f"Localization validation passed ({len(locales)} enabled locales, {len(source)} keys).")
