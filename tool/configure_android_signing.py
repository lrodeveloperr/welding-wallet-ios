#!/usr/bin/env python3
"""Inject release signing into a generated Flutter Android host."""

from __future__ import annotations

from pathlib import Path


path = Path("android/app/build.gradle.kts")
if not path.is_file():
    raise SystemExit("Missing generated android/app/build.gradle.kts")

source = path.read_text(encoding="utf-8")
if "import java.util.Properties" not in source:
    source = (
        "import java.io.FileInputStream\n"
        "import java.util.Properties\n\n"
        "val weldingKeystoreProperties = Properties()\n"
        "val weldingKeystoreFile = rootProject.file(\"key.properties\")\n"
        "require(weldingKeystoreFile.isFile) { \"Missing Android key.properties\" }\n"
        "weldingKeystoreProperties.load(FileInputStream(weldingKeystoreFile))\n\n"
        + source
    )

marker = "    buildTypes {"
signing = """    signingConfigs {
        create("release") {
            keyAlias = weldingKeystoreProperties["keyAlias"] as String
            keyPassword = weldingKeystoreProperties["keyPassword"] as String
            storeFile = file(weldingKeystoreProperties["storeFile"] as String)
            storePassword = weldingKeystoreProperties["storePassword"] as String
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
            enableV4Signing = true
        }
    }

"""
if "signingConfigs {" not in source:
    if marker not in source:
        raise SystemExit("Generated Gradle template has no buildTypes block")
    source = source.replace(marker, signing + marker, 1)

old = 'signingConfig = signingConfigs.getByName("debug")'
new = 'signingConfig = signingConfigs.getByName("release")'
if old in source:
    source = source.replace(old, new, 1)
elif new not in source:
    raise SystemExit("Generated Gradle template release signing line was not recognized")

path.write_text(source, encoding="utf-8")
print("PASS: generated Android release host uses protected upload signing")
