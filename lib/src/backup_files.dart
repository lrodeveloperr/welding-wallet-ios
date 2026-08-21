import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'domain/welding_gas_wallet_core_v1_1.dart';

class BackupFiles {
  const BackupFiles();

  Future<void> shareBackup(
    String encoded, {
    required String localizedTitle,
    required String localizedPrivacyNote,
    Rect? sharePositionOrigin,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(encoded));
    final day = DateTime.now().toUtc().toIso8601String().split('T').first;
    await SharePlus.instance.share(
      ShareParams(
        title: localizedTitle,
        subject: localizedTitle,
        text: localizedPrivacyNote,
        files: <XFile>[
          XFile.fromData(
            bytes,
            mimeType: 'application/json',
            name: 'welding-gas-wallet-$day.json',
          ),
        ],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Returns null when the platform picker was cancelled.
  Future<String?> pickBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > maximumBackupBytes) {
      throw const FormatException('Backup exceeds the maximum supported size.');
    }
    return utf8.decode(bytes, allowMalformed: false);
  }
}
