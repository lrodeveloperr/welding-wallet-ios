#!/usr/bin/env python3
"""Fail a release if its merged Android permission surface drifts."""

from __future__ import annotations

import argparse
import pathlib
import sys
import xml.etree.ElementTree as element_tree


ANDROID_NAME = "{http://schemas.android.com/apk/res/android}name"
BASE_PERMISSIONS = {
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "com.android.vending.BILLING",
}


def declared_permissions(manifest_path: pathlib.Path) -> set[str]:
    root = element_tree.parse(manifest_path).getroot()
    declarations: set[str] = set()
    for tag in ("uses-permission", "uses-permission-sdk-23"):
        for element in root.findall(tag):
            name = element.attrib.get(ANDROID_NAME, "").strip()
            if name:
                declarations.add(name)
    return declarations


def verify(manifest_path: pathlib.Path, variant: str) -> None:
    expected = set(BASE_PERMISSIONS)
    if variant == "debug":
        expected.add("android.permission.INTERNET")
    actual = declared_permissions(manifest_path)
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)
    if missing or unexpected:
        if missing:
            print("Missing required permissions: " + ", ".join(missing), file=sys.stderr)
        if unexpected:
            print("Unexpected permissions: " + ", ".join(unexpected), file=sys.stderr)
        raise SystemExit(1)
    print(f"Verified {variant} permissions: {', '.join(sorted(actual))}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=pathlib.Path)
    parser.add_argument("--variant", choices=("debug", "release"), required=True)
    arguments = parser.parse_args()
    verify(arguments.manifest, arguments.variant)


if __name__ == "__main__":
    main()
