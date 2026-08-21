#!/usr/bin/env python3
"""Fail-closed configuration for reproducibly generated Flutter host projects."""

from __future__ import annotations

import argparse
import plistlib
import re
from pathlib import Path


BUNDLE_ID = "com.goodusestudios.weldinggaswallet"
DISPLAY_NAME = "Welding Gas Wallet"
LOCALES = [
    "en", "es", "pt", "fr", "de", "it", "nl", "pl", "cs", "ro",
    "hu", "sv", "nb", "da", "fi", "tr", "ar", "hi", "bn", "id",
    "vi", "th", "ja", "ko", "zh-Hans", "zh-Hant", "uk", "el", "ms", "fil",
]
PLAY_SIGNATURE_CHANNEL = f"{BUNDLE_ID}/play_signature"

ANDROID_MAIN_ACTIVITY = f'''package {BUNDLE_ID}

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "{PLAY_SIGNATURE_CHANNEL}",
        ).setMethodCallHandler {{ call, result ->
            val licenseKey = call.argument<String>("licenseKeyBase64")
            when (call.method) {{
                "validatePlayPublicKey" -> result.success(
                    licenseKey != null && GooglePlaySignatureVerifier.validatePublicKey(licenseKey),
                )
                "verifyPlaySignature" -> {{
                    val signedData = call.argument<String>("signedData")
                    val signature = call.argument<String>("signatureBase64")
                    result.success(
                        licenseKey != null &&
                            signedData != null &&
                            signature != null &&
                            GooglePlaySignatureVerifier.verify(
                                licenseKey,
                                signedData,
                                signature,
                            ),
                    )
                }}
                else -> result.notImplemented()
            }}
        }}
    }}
}}
'''

ANDROID_PLAY_VERIFIER = f'''package {BUNDLE_ID}

import java.security.KeyFactory
import java.security.PublicKey
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import java.util.Base64

internal object GooglePlaySignatureVerifier {{
    private const val MAX_KEY_CHARS = 32_768
    private const val MAX_PAYLOAD_CHARS = 1_048_576
    private const val MAX_SIGNATURE_CHARS = 32_768

    fun validatePublicKey(licenseKeyBase64: String): Boolean =
        decodePublicKey(licenseKeyBase64) != null

    fun verify(
        licenseKeyBase64: String,
        signedData: String,
        signatureBase64: String,
    ): Boolean {{
        if (signedData.isEmpty() || signedData.length > MAX_PAYLOAD_CHARS ||
            signatureBase64.isEmpty() || signatureBase64.length > MAX_SIGNATURE_CHARS
        ) return false
        return try {{
            val publicKey = decodePublicKey(licenseKeyBase64) ?: return false
            val signatureBytes = Base64.getDecoder().decode(
                signatureBase64.filterNot(Char::isWhitespace),
            )
            val verifier = Signature.getInstance("SHA1withRSA")
            verifier.initVerify(publicKey)
            verifier.update(signedData.toByteArray(Charsets.UTF_8))
            verifier.verify(signatureBytes)
        }} catch (_: Exception) {{
            false
        }}
    }}

    private fun decodePublicKey(licenseKeyBase64: String): PublicKey? {{
        if (licenseKeyBase64.isEmpty() || licenseKeyBase64.length > MAX_KEY_CHARS) return null
        return try {{
            val keyBytes = Base64.getDecoder().decode(
                licenseKeyBase64.filterNot(Char::isWhitespace),
            )
            val key = KeyFactory.getInstance("RSA").generatePublic(
                X509EncodedKeySpec(keyBytes),
            )
            key.takeIf {{ it.algorithm == "RSA" }}
        }} catch (_: Exception) {{
            null
        }}
    }}
}}
'''

ANDROID_PLAY_VERIFIER_TEST = f'''package {BUNDLE_ID}

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GooglePlaySignatureVerifierTest {{
    @Test
    fun acceptsKnownGooglePlayStyleFixture() {{
        assertTrue(GooglePlaySignatureVerifier.validatePublicKey(PUBLIC_KEY))
        assertTrue(GooglePlaySignatureVerifier.verify(PUBLIC_KEY, PAYLOAD, SIGNATURE))
    }}

    @Test
    fun rejectsTamperingMalformedInputsAndNonKeys() {{
        assertFalse(
            GooglePlaySignatureVerifier.verify(
                PUBLIC_KEY,
                PAYLOAD.replace("annual", "monthly"),
                SIGNATURE,
            ),
        )
        assertFalse(GooglePlaySignatureVerifier.verify(PUBLIC_KEY, PAYLOAD, "AAAA"))
        assertFalse(GooglePlaySignatureVerifier.validatePublicKey("AAAA"))
    }}

    private companion object {{
        const val PUBLIC_KEY =
            "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCqY66MugW/9ggly6H0yEbU" +
                "W1UtKlAz8erfslTqSPf+Frb5KOhfB8RynLVE6/BNu7hI6vl9oZndI4smA5D" +
                "tBX8Qde+aZE1WTHn66ASveWFDl7vcqSyc6C0SsunC3GU2f1MWhWZxLg6+01" +
                "ZmcTdqHhjtfP94U2XFIZB7VdpkZ0qtlwIDAQAB"
        const val PAYLOAD =
            "{{\\\"orderId\\\":\\\"GPA.1234\\\",\\\"packageName\\\":\\\"{BUNDLE_ID}\\\"," +
                "\\\"productId\\\":\\\"com.gooduse.weldinggaswallet.pro.annual\\\"," +
                "\\\"purchaseTime\\\":1787300000000,\\\"purchaseState\\\":0," +
                "\\\"purchaseToken\\\":\\\"test-token-123\\\",\\\"quantity\\\":1," +
                "\\\"acknowledged\\\":false}}"
        const val SIGNATURE =
            "J8Ptl2lT6W6nqRHT20qIwg+7cykL2pqK/UI7JKtzpAW7vcaU9FOskh/OpwqS" +
                "u6GaAa2Wh6qEJXMq0GqD3RjmIXaRre1ZIh9oeh0oWVpJbT/e7G0gYiiUizG" +
                "Il1MZ32bJnUo5RQmKEvMvvBh/ntjDHJiKw88Sut1zuqc560qH1k8="
    }}
}}
'''


def replace_exact(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Host configuration failed: missing {label}: {old!r}")
    return text.replace(old, new)


def configure_android(root: Path) -> None:
    app_gradle = root / "android/app/build.gradle.kts"
    settings_gradle = root / "android/settings.gradle.kts"
    manifest = root / "android/app/src/main/AndroidManifest.xml"
    if not app_gradle.is_file() or not settings_gradle.is_file() or not manifest.is_file():
        raise SystemExit("Host configuration failed: generated Android host is incomplete")

    gradle = app_gradle.read_text(encoding="utf-8")
    if f'applicationId = "{BUNDLE_ID}"' not in gradle:
        gradle = re.sub(
            r'applicationId\s*=\s*"[^"]+"',
            f'applicationId = "{BUNDLE_ID}"',
            gradle,
            count=1,
        )
    if f'namespace = "{BUNDLE_ID}"' not in gradle:
        gradle = re.sub(
            r'namespace\s*=\s*"[^"]+"',
            f'namespace = "{BUNDLE_ID}"',
            gradle,
            count=1,
        )
    gradle, compile_count = re.subn(
        r"compileSdk\s*=\s*(?:flutter\.compileSdkVersion|\d+)",
        "compileSdk = 36",
        gradle,
        count=1,
    )
    gradle, min_count = re.subn(
        r"minSdk\s*=\s*(?:flutter\.minSdkVersion|\d+)",
        "minSdk = 26",
        gradle,
        count=1,
    )
    gradle, target_count = re.subn(
        r"targetSdk\s*=\s*(?:flutter\.targetSdkVersion|\d+)",
        "targetSdk = 36",
        gradle,
        count=1,
    )
    if (compile_count, min_count, target_count) != (1, 1, 1):
        raise SystemExit("Host configuration failed: Android SDK settings did not match the pinned template")

    gradle, source_count = re.subn(
        r"sourceCompatibility\s*=\s*JavaVersion\.VERSION_\d+",
        "sourceCompatibility = JavaVersion.VERSION_17",
        gradle,
        count=1,
    )
    gradle, target_java_count = re.subn(
        r"targetCompatibility\s*=\s*JavaVersion\.VERSION_\d+",
        "targetCompatibility = JavaVersion.VERSION_17",
        gradle,
        count=1,
    )
    if (source_count, target_java_count) != (1, 1):
        raise SystemExit("Host configuration failed: Java compile options were not found")
    if "isCoreLibraryDesugaringEnabled = true" not in gradle:
        gradle, desugar_count = re.subn(
            r"(compileOptions\s*\{)",
            r"\1\n        isCoreLibraryDesugaringEnabled = true",
            gradle,
            count=1,
        )
        if desugar_count != 1:
            raise SystemExit("Host configuration failed: compileOptions block was not found")

    if re.search(r"jvmTarget\s*=", gradle):
        gradle = re.sub(
            r"jvmTarget\s*=\s*JavaVersion\.VERSION_\d+\.toString\(\)",
            "jvmTarget = JavaVersion.VERSION_17.toString()",
            gradle,
            count=1,
        )

    default_match = re.search(r"defaultConfig\s*\{", gradle)
    if default_match is None:
        raise SystemExit("Host configuration failed: defaultConfig block was not found")
    if "multiDexEnabled = true" not in gradle:
        gradle = (
            gradle[: default_match.end()]
            + "\n        multiDexEnabled = true"
            + gradle[default_match.end() :]
        )

    desugar_dependency = (
        'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
    )
    junit_dependency = 'testImplementation("junit:junit:4.13.2")'
    if desugar_dependency not in gradle:
        gradle = gradle.rstrip() + (
            "\n\ndependencies {\n"
            f"    {desugar_dependency}\n"
            f"    {junit_dependency}\n"
            "}\n"
        )
    elif junit_dependency not in gradle:
        gradle = replace_exact(
            gradle,
            desugar_dependency,
            f"{desugar_dependency}\n    {junit_dependency}",
            "core desugaring dependency",
        )
    if BUNDLE_ID not in gradle:
        raise SystemExit("Host configuration failed: Android application ID was not applied")
    for required in (
        "isCoreLibraryDesugaringEnabled = true",
        "JavaVersion.VERSION_17",
        "multiDexEnabled = true",
        desugar_dependency,
        junit_dependency,
    ):
        if required not in gradle:
            raise SystemExit(f"Host configuration failed: missing Android requirement {required!r}")
    app_gradle.write_text(gradle, encoding="utf-8")

    settings = settings_gradle.read_text(encoding="utf-8")
    agp_match = re.search(
        r'id\("com\.android\.application"\)\s+version\s+"(\d+)\.(\d+)\.(\d+)"',
        settings,
    )
    if agp_match is None:
        raise SystemExit("Host configuration failed: Android Gradle Plugin version was not found")
    agp_version = tuple(int(part) for part in agp_match.groups())
    if agp_version < (8, 11, 1):
        raise SystemExit(
            "Host configuration failed: flutter_local_notifications 22.3.0 "
            f"requires Android Gradle Plugin 8.11.1+, found {agp_version}"
        )

    xml = manifest.read_text(encoding="utf-8")
    xml = re.sub(r'android:label="[^"]+"', f'android:label="{DISPLAY_NAME}"', xml, count=1)
    if "android:allowBackup=" not in xml:
        xml = re.sub(
            r"<application\s+",
            '<application\n        android:allowBackup="false"\n'
            '        android:fullBackupContent="false"\n'
            '        android:supportsRtl="true"\n'
            '        android:localeConfig="@xml/locales_config"\n        ',
            xml,
            count=1,
        )
    elif not all(
        required in xml
        for required in (
            'android:allowBackup="false"',
            'android:fullBackupContent="false"',
            'android:supportsRtl="true"',
            'android:localeConfig="@xml/locales_config"',
        )
    ):
        raise SystemExit("Host configuration failed: existing Android backup/locale policy conflicts")
    if "android.permission.POST_NOTIFICATIONS" not in xml:
        xml = xml.replace(
            "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">",
            "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">\n"
            "    <uses-permission android:name=\"android.permission.POST_NOTIFICATIONS\" />",
        )
    if "android.permission.RECEIVE_BOOT_COMPLETED" not in xml:
        xml = xml.replace(
            "<application\n",
            "<uses-permission android:name=\"android.permission.RECEIVE_BOOT_COMPLETED\" />\n\n"
            "    <application\n",
            1,
        )
    scheduled_receivers = (
        "\n        <receiver\n"
        "            android:name=\"com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver\"\n"
        "            android:exported=\"false\" />\n"
        "        <receiver\n"
        "            android:name=\"com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver\"\n"
        "            android:exported=\"false\">\n"
        "            <intent-filter>\n"
        "                <action android:name=\"android.intent.action.BOOT_COMPLETED\" />\n"
        "                <action android:name=\"android.intent.action.MY_PACKAGE_REPLACED\" />\n"
        "                <action android:name=\"android.intent.action.QUICKBOOT_POWERON\" />\n"
        "                <action android:name=\"com.htc.intent.action.QUICKBOOT_POWERON\" />\n"
        "            </intent-filter>\n"
        "        </receiver>\n"
    )
    if "ScheduledNotificationReceiver" not in xml:
        xml = xml.replace("\n    </application>", scheduled_receivers + "    </application>", 1)
    if DISPLAY_NAME not in xml or "@xml/locales_config" not in xml:
        raise SystemExit("Host configuration failed: Android manifest settings were not applied")
    for required in (
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "ScheduledNotificationReceiver",
        "ScheduledNotificationBootReceiver",
    ):
        if required not in xml:
            raise SystemExit(f"Host configuration failed: missing notification requirement {required!r}")
    if "EXACT_ALARM" in xml:
        raise SystemExit("Host configuration failed: exact-alarm permission is not permitted")
    manifest.write_text(xml, encoding="utf-8")

    kotlin_package = Path(*BUNDLE_ID.split("."))
    kotlin_dir = root / "android/app/src/main/kotlin" / kotlin_package
    main_activity = kotlin_dir / "MainActivity.kt"
    generated_activities = list(
        (root / "android/app/src/main/kotlin").rglob("MainActivity.kt")
    )
    if generated_activities != [main_activity]:
        raise SystemExit(
            "Host configuration failed: generated MainActivity package does not "
            f"match {BUNDLE_ID}: {generated_activities}"
        )
    kotlin_dir.mkdir(parents=True, exist_ok=True)
    main_activity.write_text(ANDROID_MAIN_ACTIVITY, encoding="utf-8")
    (kotlin_dir / "GooglePlaySignatureVerifier.kt").write_text(
        ANDROID_PLAY_VERIFIER,
        encoding="utf-8",
    )
    kotlin_test_dir = root / "android/app/src/test/kotlin" / kotlin_package
    kotlin_test_dir.mkdir(parents=True, exist_ok=True)
    (kotlin_test_dir / "GooglePlaySignatureVerifierTest.kt").write_text(
        ANDROID_PLAY_VERIFIER_TEST,
        encoding="utf-8",
    )

    xml_dir = root / "android/app/src/main/res/xml"
    xml_dir.mkdir(parents=True, exist_ok=True)
    locale_lines = "\n".join(
        f'    <locale android:name="{locale}" />' for locale in LOCALES
    )
    (xml_dir / "locales_config.xml").write_text(
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        "<locale-config xmlns:android=\"http://schemas.android.com/apk/res/android\">\n"
        f"{locale_lines}\n"
        "</locale-config>\n",
        encoding="utf-8",
    )

    drawable_dir = root / "android/app/src/main/res/drawable"
    drawable_dir.mkdir(parents=True, exist_ok=True)
    (drawable_dir / "ic_stat_welding_wallet.xml").write_text(
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        "<vector xmlns:android=\"http://schemas.android.com/apk/res/android\"\n"
        "    android:width=\"24dp\" android:height=\"24dp\"\n"
        "    android:viewportWidth=\"24\" android:viewportHeight=\"24\">\n"
        "    <path android:fillColor=\"#FFFFFFFF\"\n"
        "        android:pathData=\"M10,2h4v2h1a3,3 0,0 1,3 3v13a2,2 0,0 1,-2 2H8a2,2 0,0 1,-2,-2V7a3,3 0,0 1,3,-3h1z\" />\n"
        "</vector>\n",
        encoding="utf-8",
    )
    raw_dir = root / "android/app/src/main/res/raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    (raw_dir / "keep.xml").write_text(
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        "<resources xmlns:tools=\"http://schemas.android.com/tools\"\n"
        "    tools:keep=\"@drawable/ic_stat_welding_wallet\" />\n",
        encoding="utf-8",
    )


def configure_ios(root: Path) -> None:
    project = root / "ios/Runner.xcodeproj/project.pbxproj"
    info = root / "ios/Runner/Info.plist"
    podfile = root / "ios/Podfile"
    app_delegate = root / "ios/Runner/AppDelegate.swift"
    if not project.is_file() or not info.is_file() or not app_delegate.is_file():
        raise SystemExit("Host configuration failed: generated iOS host is incomplete")

    text = project.read_text(encoding="utf-8")

    def bundle(match: re.Match[str]) -> str:
        current = match.group(1).strip().strip('"')
        suffix = ".RunnerTests" if current.lower().endswith("runnertests") else ""
        return f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}{suffix};"

    text, bundle_count = re.subn(
        r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", bundle, text
    )
    text, deployment_count = re.subn(
        r"IPHONEOS_DEPLOYMENT_TARGET = [^;]+;",
        "IPHONEOS_DEPLOYMENT_TARGET = 15.0;",
        text,
    )
    if bundle_count < 2 or deployment_count < 1 or BUNDLE_ID not in text:
        raise SystemExit("Host configuration failed: iOS project settings were not applied")
    project.write_text(text, encoding="utf-8")

    with info.open("rb") as handle:
        plist = plistlib.load(handle)
    plist["CFBundleDisplayName"] = DISPLAY_NAME
    plist["CFBundleName"] = DISPLAY_NAME
    plist["CFBundleDevelopmentRegion"] = "en"
    plist["CFBundleLocalizations"] = LOCALES
    # Export classification must be supported by the Account Holder's current
    # App Store Connect questionnaire/evidence. Never assert an exemption merely
    # to suppress TestFlight's Missing Compliance state.
    plist.pop("ITSAppUsesNonExemptEncryption", None)
    plist["UIFileSharingEnabled"] = False
    plist["LSSupportsOpeningDocumentsInPlace"] = True
    with info.open("wb") as handle:
        plistlib.dump(plist, handle, sort_keys=False)

    delegate = app_delegate.read_text(encoding="utf-8")
    if "import UserNotifications" not in delegate:
        delegate = replace_exact(
            delegate,
            "import UIKit\n",
            "import UIKit\nimport UserNotifications\n",
            "AppDelegate UIKit import",
        )
    presentation_delegate = "UNUserNotificationCenter.current().delegate = self"
    if presentation_delegate not in delegate:
        delegate = re.sub(
            r"(override func application\([\s\S]*?didFinishLaunchingWithOptions[\s\S]*?\{\n)",
            r"\1    UNUserNotificationCenter.current().delegate = self\n",
            delegate,
            count=1,
        )
    if "import UserNotifications" not in delegate or presentation_delegate not in delegate:
        raise SystemExit("Host configuration failed: iOS notification delegate was not applied")
    app_delegate.write_text(delegate, encoding="utf-8")

    if podfile.is_file():
        pod = podfile.read_text(encoding="utf-8")
        if re.search(r"(?m)^platform :ios,", pod):
            pod = re.sub(r"(?m)^platform :ios,.*$", "platform :ios, '15.0'", pod)
        else:
            pod = "platform :ios, '15.0'\n" + pod
        podfile.write_text(pod, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("platform", choices=("android", "ios", "both"))
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    if args.platform in {"android", "both"}:
        configure_android(args.root)
    if args.platform in {"ios", "both"}:
        configure_ios(args.root)
    print(f"PASS: configured {args.platform} host for {BUNDLE_ID}; {len(LOCALES)} locales")


if __name__ == "__main__":
    main()
