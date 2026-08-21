from __future__ import annotations

import pathlib
import tempfile
import unittest

from verify_android_manifest import verify


class VerifyAndroidManifestTest(unittest.TestCase):
    def _manifest(self, permissions: list[str]) -> pathlib.Path:
        temp_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temp_directory.cleanup)
        path = pathlib.Path(temp_directory.name) / "AndroidManifest.xml"
        rows = [
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
            *(f'  <uses-permission android:name="{permission}" />' for permission in permissions),
            "  <application />",
            "</manifest>",
        ]
        path.write_text("\n".join(rows), encoding="utf-8")
        return path

    def test_release_accepts_only_reviewed_permissions(self) -> None:
        verify(
            self._manifest(
                [
                    "android.permission.POST_NOTIFICATIONS",
                    "android.permission.RECEIVE_BOOT_COMPLETED",
                    "com.android.vending.BILLING",
                ]
            ),
            "release",
        )

    def test_release_rejects_permission_drift(self) -> None:
        path = self._manifest(
            [
                "android.permission.POST_NOTIFICATIONS",
                "android.permission.RECEIVE_BOOT_COMPLETED",
                "com.android.vending.BILLING",
                "android.permission.READ_CONTACTS",
            ]
        )
        with self.assertRaises(SystemExit):
            verify(path, "release")


if __name__ == "__main__":
    unittest.main()
