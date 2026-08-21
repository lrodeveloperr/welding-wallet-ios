from __future__ import annotations

import plistlib
import tempfile
import unittest
import xml.etree.ElementTree as element_tree
from pathlib import Path

from configure_hosts import (
    BUNDLE_ID,
    LOCALES,
    PLAY_SIGNATURE_CHANNEL,
    configure_android,
    configure_ios,
)


class ConfigureHostsTest(unittest.TestCase):
    def test_android_configuration_is_complete_and_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / "android/app"
            manifest = app / "src/main/AndroidManifest.xml"
            manifest.parent.mkdir(parents=True)
            (app / "build.gradle.kts").write_text(
                """android {
    namespace = "com.example.placeholder"
    compileSdk = flutter.compileSdkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    defaultConfig {
        applicationId = "com.example.placeholder"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
    }
}
""",
                encoding="utf-8",
            )
            (root / "android/settings.gradle.kts").write_text(
                'plugins { id("com.android.application") version "8.11.1" apply false }\n',
                encoding="utf-8",
            )
            manifest.write_text(
                """<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="placeholder" android:icon="@mipmap/ic_launcher">
        <activity android:name=".MainActivity" />
    </application>
</manifest>
""",
                encoding="utf-8",
            )
            kotlin_dir = app / "src/main/kotlin" / Path(*BUNDLE_ID.split("."))
            kotlin_dir.mkdir(parents=True)
            (kotlin_dir / "MainActivity.kt").write_text(
                f"package {BUNDLE_ID}\n\nclass MainActivity\n",
                encoding="utf-8",
            )

            configure_android(root)
            configure_android(root)

            gradle = (app / "build.gradle.kts").read_text(encoding="utf-8")
            self.assertEqual(gradle.count("isCoreLibraryDesugaringEnabled = true"), 1)
            self.assertEqual(gradle.count("desugar_jdk_libs:2.1.4"), 1)
            self.assertEqual(gradle.count("junit:junit:4.13.2"), 1)
            self.assertIn("compileSdk = 36", gradle)
            self.assertIn("minSdk = 26", gradle)
            self.assertIn("targetSdk = 36", gradle)
            self.assertIn(f'applicationId = "{BUNDLE_ID}"', gradle)

            xml = manifest.read_text(encoding="utf-8")
            element_tree.fromstring(xml)
            self.assertEqual(xml.count("ScheduledNotificationReceiver"), 1)
            self.assertEqual(xml.count("ScheduledNotificationBootReceiver"), 1)
            self.assertNotIn("EXACT_ALARM", xml)
            self.assertTrue((app / "src/main/res/raw/keep.xml").is_file())
            self.assertTrue(
                (app / "src/main/res/drawable/ic_stat_welding_wallet.xml").is_file()
            )
            locale_config = (app / "src/main/res/xml/locales_config.xml").read_text(
                encoding="utf-8"
            )
            self.assertEqual(locale_config.count("<locale "), len(LOCALES))
            activity = (kotlin_dir / "MainActivity.kt").read_text(encoding="utf-8")
            verifier = (kotlin_dir / "GooglePlaySignatureVerifier.kt").read_text(
                encoding="utf-8"
            )
            fixture = (
                app
                / "src/test/kotlin"
                / Path(*BUNDLE_ID.split("."))
                / "GooglePlaySignatureVerifierTest.kt"
            ).read_text(encoding="utf-8")
            self.assertEqual(activity.count(PLAY_SIGNATURE_CHANNEL), 1)
            self.assertIn('"validatePlayPublicKey"', activity)
            self.assertIn('"verifyPlaySignature"', activity)
            self.assertIn('Signature.getInstance("SHA1withRSA")', verifier)
            self.assertIn("X509EncodedKeySpec", verifier)
            self.assertIn("acceptsKnownGooglePlayStyleFixture", fixture)
            self.assertIn("rejectsTamperingMalformedInputsAndNonKeys", fixture)

    def test_ios_configuration_is_complete_and_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            runner = root / "ios/Runner"
            project = root / "ios/Runner.xcodeproj/project.pbxproj"
            runner.mkdir(parents=True)
            project.parent.mkdir(parents=True)
            project.write_text(
                """PRODUCT_BUNDLE_IDENTIFIER = com.example.placeholder;
PRODUCT_BUNDLE_IDENTIFIER = com.example.placeholder.RunnerTests;
IPHONEOS_DEPLOYMENT_TARGET = 13.0;
""",
                encoding="utf-8",
            )
            with (runner / "Info.plist").open("wb") as handle:
                plistlib.dump({"CFBundleDisplayName": "placeholder"}, handle)
            (runner / "AppDelegate.swift").write_text(
                """import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
""",
                encoding="utf-8",
            )
            (root / "ios/Podfile").write_text("# platform :ios, '13.0'\n", encoding="utf-8")

            configure_ios(root)
            configure_ios(root)

            delegate = (runner / "AppDelegate.swift").read_text(encoding="utf-8")
            self.assertEqual(delegate.count("import UserNotifications"), 1)
            self.assertEqual(
                delegate.count("UNUserNotificationCenter.current().delegate = self"),
                1,
            )
            with (runner / "Info.plist").open("rb") as handle:
                info = plistlib.load(handle)
            self.assertEqual(info["CFBundleDisplayName"], "Welding Gas Wallet")
            self.assertEqual(info["CFBundleLocalizations"], LOCALES)
            self.assertNotIn("ITSAppUsesNonExemptEncryption", info)
            self.assertIn(BUNDLE_ID, project.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
