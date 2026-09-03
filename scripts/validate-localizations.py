#!/usr/bin/env python3
"""Release gate: exposed locales must be complete and catalog keys must match."""

from pathlib import Path
from collections import Counter
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "Shell/App/ShellConfiguration.swift"
CATALOG_ROOT = ROOT / "Shell/Resources"
GLOSSARY_PATH = CATALOG_ROOT / "welding-localization-glossary.json"

locales = re.findall(r'\.init\(id: "([^"]+)", displayName:', CONFIG.read_text())
EXPECTED_LOCALES = [
    "en", "es-419",
]
if locales != EXPECTED_LOCALES:
    sys.exit(f"LOCALIZATION FAILED: language options/order differ from the approved 31 locales: {locales}")

INTERNATIONAL_UNCHANGED_KEYS = {
    "ok", "0.00", " · ", "Argon", "C25 Mix", "Oxygen", "Acetylene",
    "Nitrogen", "CO₂", "Helium",
}
GLOSSARY_KEYS = {
    "destination.cylinders": "cylinders", "Cylinders": "cylinders",
    "Cylinder": "cylinder", "cylinders.active.label": "active",
    "cylinders.current.label": "current", "status.low": "low",
    "status.away": "away", "activity.kind.refill": "refill",
    "Refill": "refill", "Supplier": "supplier",
    "delete.confirmationWord": "delete", "delete.typeWord": "typeDelete",
}
if not GLOSSARY_PATH.is_file():
    sys.exit("LOCALIZATION FAILED: missing welding terminology contract")
glossary = json.loads(GLOSSARY_PATH.read_text())
if len(glossary) != 31 or not set(EXPECTED_LOCALES).issubset(glossary):
    sys.exit("LOCALIZATION FAILED: welding terminology contract does not cover all 31 target locales")

def catalog(path: Path) -> dict[str, str]:
    found = re.findall(
        r'^\s*"((?:\\.|[^"])*)"\s*=\s*"((?:\\.|[^"])*)"\s*;',
        path.read_text(),
        re.MULTILINE,
    )
    found_keys = [key for key, _ in found]
    if len(found_keys) != len(set(found_keys)):
        sys.exit(f"LOCALIZATION FAILED: duplicate keys in {path.relative_to(ROOT)}")
    return dict(found)

def placeholders(value: str) -> Counter[str]:
    return Counter(re.findall(r'%(?:\d+\$)?(@|lld|ld|d|f|s)', value))

english = CATALOG_ROOT / "en.lproj/Localizable.strings"
if not english.is_file():
    sys.exit("LOCALIZATION FAILED: missing English source catalog")
source_catalog = catalog(english)
source = set(source_catalog)

for locale in locales:
    path = CATALOG_ROOT / f"{locale}.lproj/Localizable.strings"
    if not path.is_file():
        sys.exit(f"LOCALIZATION FAILED: enabled locale {locale} has no catalog")
    current_catalog = catalog(path)
    current = set(current_catalog)
    missing = sorted(source - current)
    extra = sorted(current - source)
    if missing or extra:
        sys.exit(
            f"LOCALIZATION FAILED: {locale} key mismatch; "
            f"missing={missing[:8]} extra={extra[:8]}"
        )
    mismatched_placeholders = sorted(
        key for key in source
        if placeholders(source_catalog[key]) != placeholders(current_catalog[key])
    )
    if mismatched_placeholders:
        sys.exit(
            f"LOCALIZATION FAILED: {locale} placeholder mismatch; "
            f"keys={mismatched_placeholders[:8]}"
        )
    empty = sorted(key for key, value in current_catalog.items() if not value.strip())
    multiline = sorted(key for key, value in current_catalog.items() if "\n" in value or "\\n" in value)
    if empty or multiline:
        sys.exit(
            f"LOCALIZATION FAILED: {locale} contains empty or cross-key text; "
            f"empty={empty[:8]} multiline={multiline[:8]}"
        )
    if locale != "en":
        untranslated = sorted(
            key for key in source
            if key not in INTERNATIONAL_UNCHANGED_KEYS
            and len(source_catalog[key]) >= 12
            and re.search(r"[A-Za-z]{4}", source_catalog[key])
            and current_catalog[key].casefold() == source_catalog[key].casefold()
        )
        if untranslated:
            sys.exit(
                f"LOCALIZATION FAILED: {locale} contains likely English fallback prose; "
                f"keys={untranslated[:8]}"
            )
    terminology_drift = sorted(
        key for key, term in GLOSSARY_KEYS.items()
        if current_catalog.get(key) != glossary[locale][term]
    )
    if terminology_drift:
        sys.exit(
            f"LOCALIZATION FAILED: {locale} drifts from the reviewed welding glossary; "
            f"keys={terminology_drift[:8]}"
        )

ui_files = sorted(
    path for path in (ROOT / "Shell").rglob("*.swift")
    if path.name != "ShellLabView.swift"  # DEBUG-only developer instrumentation
)
ui_pattern = re.compile(
    r'(?:Text|Button|Section|TextField|Toggle|Menu|ContentUnavailableView|navigationTitle|accessibilityLabel|alert|confirmationDialog|Label|LabeledContent)\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'
)
uncatalogued: list[str] = []
for ui_file in ui_files:
    for key in ui_pattern.findall(ui_file.read_text()):
        if "\\(" not in key and key not in source:
            uncatalogued.append(f"{ui_file.relative_to(ROOT)}: {key}")
if uncatalogued:
    sys.exit("LOCALIZATION FAILED: uncatalogued UI literals: " + "; ".join(uncatalogued[:12]))

print(f"Localization validation passed ({len(locales)} enabled locales, {len(source)} keys).")
