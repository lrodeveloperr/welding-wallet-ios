import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'domain/welding_gas_wallet_core_v1_1.dart';

class StorageCorruptionException implements Exception {
  const StorageCorruptionException(this.quarantinedPath, this.cause);

  final String quarantinedPath;
  final Object cause;

  @override
  String toString() =>
      'Wallet storage was quarantined at $quarantinedPath: $cause';
}

class FileWalletRepository
    implements
        AtomicWalletRepository,
        SessionEntitlementTrust,
        ResidualWalletDataPurger,
        CorruptionRecoveryRepository {
  FileWalletRepository({
    required Directory directory,
    this.fileName = 'welding-gas-wallet-v2.json',
    this.initialLocale = 'en',
    this.initialCurrencyCode,
  }) : _directory = directory;

  final Directory _directory;
  final String fileName;
  final String initialLocale;
  final String? initialCurrencyCode;
  Future<void> _tail = Future<void>.value();
  Entitlement _sessionEntitlement = const Entitlement.free();

  File get _file => File(
        '${_directory.path}${Platform.pathSeparator}$fileName',
      );
  File get _previous => File('${_file.path}.previous');
  File get _recovery => File('${_file.path}.recovery');
  File get _temporary => File('${_file.path}.tmp');
  File get _corruptionMarker => File('${_file.path}.corruption-marker');

  @override
  Future<WalletData> read() => _exclusive(_readUnlocked);

  Future<WalletData> _readUnlocked() async {
    await _directory.create(recursive: true);
    final quarantines = await _quarantinedFiles();
    if (await _corruptionMarker.exists() ||
        (!await _file.exists() && quarantines.isNotEmpty)) {
      final quarantinePath = await _corruptionMarker.exists()
          ? await _corruptionMarker.readAsString()
          : quarantines.first.path;
      throw StorageCorruptionException(
        quarantinePath,
        StateError('Explicit recovery, import, or clearing is required.'),
      );
    }
    if (!await _file.exists() && await _previous.exists()) {
      await _previous.rename(_file.path);
    }
    if (!await _file.exists()) {
      return WalletData.empty(
        locale: initialLocale,
        currencyCode: initialCurrencyCode,
      );
    }
    try {
      return _withSessionEntitlement(
        WalletStorageCodec.decode(await _file.readAsString()),
      );
    } on Object catch (error) {
      final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      final quarantine = File('${_file.path}.corrupt.$stamp');
      try {
        await _file.rename(quarantine.path);
      } on Object {
        await _file.copy(quarantine.path);
      }
      await _corruptionMarker.writeAsString(quarantine.path, flush: true);
      throw StorageCorruptionException(quarantine.path, error);
    }
  }

  @override
  void acceptStoreVerifiedEntitlement(Entitlement entitlement) {
    _sessionEntitlement = entitlement;
  }

  @override
  Future<void> purgeResidualWalletFiles() =>
      _exclusive(_purgeResidualUnlocked);

  @override
  Future<WalletData> replaceCorruptStore(WalletData validatedBackup) =>
      _exclusive(() async {
        _sessionEntitlement = const Entitlement.free();
        final recovered = WalletData(
          schemaVersion: walletSchemaVersion,
          revision: 1,
          settings: validatedBackup.settings,
          suppliers: validatedBackup.suppliers,
          cylinders: validatedBackup.cylinders,
          events: validatedBackup.events,
          reminders: validatedBackup.reminders.map((reminder) => reminder.copyWith(
                delivery: reminder.completed
                    ? ReminderDelivery.needsCancellation
                    : ReminderDelivery.needsScheduling,
              )).toList(),
          pendingDraft: validatedBackup.pendingDraft,
          entitlementCache: const Entitlement.free(),
        );
        await _prepareExplicitRecoveryUnlocked();
        await _writeUnlocked(recovered);
        await _purgeResidualUnlocked();
        return recovered;
      });

  @override
  Future<WalletData> clearCorruptStore({required bool confirmed}) =>
      _exclusive(() async {
        if (!confirmed) throw StateError('Explicit confirmation is required.');
        _sessionEntitlement = const Entitlement.free();
        final cleared = WalletData.empty(
          locale: initialLocale,
          currencyCode: initialCurrencyCode,
        );
        await _prepareExplicitRecoveryUnlocked();
        await _writeUnlocked(cleared);
        await _purgeResidualUnlocked();
        return cleared;
      });

  WalletData _withSessionEntitlement(WalletData decoded) => WalletData(
        schemaVersion: decoded.schemaVersion,
        revision: decoded.revision,
        settings: decoded.settings,
        suppliers: decoded.suppliers,
        cylinders: decoded.cylinders,
        events: decoded.events,
        reminders: decoded.reminders,
        pendingDraft: decoded.pendingDraft,
        // Never authorize from the JSON field. Only the current process's
        // native-store verification can populate this session value.
        entitlementCache: _sessionEntitlement,
      );

  @override
  Future<T> transact<T>(
    TransactionOutcome<T> Function(WalletData current) mutation, {
    int? expectedRevision,
  }) =>
      _exclusive(() async {
        final current = await _readUnlocked();
        if (expectedRevision != null && current.revision != expectedRevision) {
          throw WalletConflictException(expectedRevision, current.revision);
        }
        final outcome = mutation(current);
        if (!identical(outcome.state, current)) {
          if (outcome.state.revision <= current.revision) {
            throw StateError('A persisted mutation must advance the revision.');
          }
          await _writeUnlocked(outcome.state);
        }
        return outcome.value;
      });

  @override
  Future<WalletData> replaceFromBackup(
    WalletData imported, {
    required int expectedRevision,
  }) =>
      _exclusive(() async {
        final current = await _readUnlocked();
        if (current.revision != expectedRevision) {
          throw WalletConflictException(expectedRevision, current.revision);
        }
        final replacement = WalletData(
          schemaVersion: walletSchemaVersion,
          revision: current.revision + 1,
          settings: imported.settings,
          suppliers: imported.suppliers,
          cylinders: imported.cylinders,
          events: imported.events,
          reminders: imported.reminders,
          pendingDraft: imported.pendingDraft,
          entitlementCache: current.entitlementCache,
        );
        await _writeUnlocked(replacement);
        return replacement;
      });

  Future<void> _writeUnlocked(WalletData state) async {
    await _directory.create(recursive: true);
    final temp = _temporary;
    await temp.writeAsString(
      WalletStorageCodec.encode(state),
      flush: true,
    );
    if (await _previous.exists()) await _previous.delete();
    if (await _file.exists()) {
      await _file.rename(_previous.path);
    }
    try {
      await temp.rename(_file.path);
      if (await _previous.exists()) {
        await _previous.copy(_recovery.path);
        await _previous.delete();
      }
    } on Object {
      if (!await _file.exists() && await _previous.exists()) {
        await _previous.rename(_file.path);
      }
      rethrow;
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<List<File>> _quarantinedFiles() async {
    if (!await _directory.exists()) return <File>[];
    final prefix = '$fileName.corrupt.';
    return _directory
        .list()
        .where((entity) {
          final name = entity.path.split(Platform.pathSeparator).last;
          return entity is File && name.startsWith(prefix);
        })
        .cast<File>()
        .toList();
  }

  Future<void> _prepareExplicitRecoveryUnlocked() async {
    for (final file in <File>[_file, _previous, _recovery, _temporary]) {
      if (await file.exists()) await file.delete();
    }
    // Keep the corruption marker and quarantined copy until the replacement
    // has been durably written; a write failure therefore remains fail-closed.
  }

  Future<void> _purgeResidualUnlocked() async {
    final quarantines = await _quarantinedFiles();
    for (final file in <File>[
      _previous,
      _recovery,
      _temporary,
      _corruptionMarker,
      ...quarantines,
    ]) {
      if (await file.exists()) await file.delete();
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    final previous = _tail;
    _tail = previous.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

class MemoryWalletRepository implements AtomicWalletRepository {
  MemoryWalletRepository([WalletData? seed]) : _state = seed ?? WalletData.empty();

  WalletData _state;
  Future<void> _tail = Future<void>.value();

  @override
  Future<WalletData> read() => _exclusive(() async => _state);

  @override
  Future<T> transact<T>(
    TransactionOutcome<T> Function(WalletData current) mutation, {
    int? expectedRevision,
  }) =>
      _exclusive(() async {
        if (expectedRevision != null && _state.revision != expectedRevision) {
          throw WalletConflictException(expectedRevision, _state.revision);
        }
        final outcome = mutation(_state);
        _state = outcome.state;
        return outcome.value;
      });

  @override
  Future<WalletData> replaceFromBackup(
    WalletData imported, {
    required int expectedRevision,
  }) =>
      _exclusive(() async {
        if (_state.revision != expectedRevision) {
          throw WalletConflictException(expectedRevision, _state.revision);
        }
        _state = WalletData(
          schemaVersion: walletSchemaVersion,
          revision: _state.revision + 1,
          settings: imported.settings,
          suppliers: imported.suppliers,
          cylinders: imported.cylinders,
          events: imported.events,
          reminders: imported.reminders,
          pendingDraft: imported.pendingDraft,
          entitlementCache: _state.entitlementCache,
        );
        return _state;
      });

  Future<T> _exclusive<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    final previous = _tail;
    _tail = previous.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

abstract final class WalletStorageCodec {
  static String encode(WalletData state) => jsonEncode(<String, Object?>{
        'format': 'welding-gas-wallet-private-store',
        'schemaVersion': walletSchemaVersion,
        'revision': state.revision,
        'settings': state.settings.toJson(),
        'suppliers': state.suppliers.map((value) => value.toJson()).toList(),
        'cylinders': state.cylinders.map((value) => value.toJson()).toList(),
        'events': state.events.map((value) => value.toJson()).toList(),
        'reminders': state.reminders.map((value) => value.toJson()).toList(),
        'pendingDraft': state.pendingDraft?.toJson(),
        'entitlement': <String, Object?>{
          'tier': state.entitlementCache.tier.name,
          'source': state.entitlementCache.source.name,
          'validUntil':
              state.entitlementCache.validUntil?.toUtc().toIso8601String(),
          'willRenew': state.entitlementCache.willRenew,
        },
      });

  static WalletData decode(String encoded) {
    final Object? raw = jsonDecode(encoded);
    if (raw is! Map<Object?, Object?>) {
      throw const FormatException('Private wallet store must be an object.');
    }
    final json = Map<String, Object?>.from(raw);
    if (json['format'] != 'welding-gas-wallet-private-store' ||
        (json['schemaVersion'] as num?)?.toInt() != walletSchemaVersion) {
      throw const FormatException('Unsupported private wallet store.');
    }
    final settings = _map(json['settings'], 'settings');
    final entitlementJson = _map(json['entitlement'], 'entitlement');
    final tier = _enumByName(
      AccessTier.values,
      entitlementJson['tier'],
      AccessTier.free,
    );
    final source = _enumByName(
      EntitlementSource.values,
      entitlementJson['source'],
      EntitlementSource.none,
    );
    final validUntilText = entitlementJson['validUntil']?.toString();
    final validUntil = validUntilText == null
        ? null
        : DateTime.tryParse(validUntilText)?.toUtc();
    if (validUntilText != null && validUntil == null) {
      throw const FormatException('Invalid entitlement expiry.');
    }
    return WalletData(
      schemaVersion: walletSchemaVersion,
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      settings: AppSettings.fromJson(settings),
      suppliers: _maps(json['suppliers'], 'suppliers')
          .map(Supplier.fromJson)
          .toList(growable: false),
      cylinders: _maps(json['cylinders'], 'cylinders')
          .map(Cylinder.fromJson)
          .toList(growable: false),
      events: _maps(json['events'], 'events')
          .map(CylinderEvent.fromJson)
          .toList(growable: false),
      reminders: _maps(json['reminders'], 'reminders')
          .map(Reminder.fromJson)
          .toList(growable: false),
      pendingDraft: json['pendingDraft'] == null
          ? null
          : AddCylinderDraft.fromJson(
              _map(json['pendingDraft'], 'pendingDraft'),
            ),
      entitlementCache: Entitlement(
        tier: tier,
        source: source,
        validUntil: validUntil,
        willRenew: entitlementJson['willRenew'] == true,
      ),
    );
  }

  static Map<String, Object?> _map(Object? raw, String field) {
    if (raw is! Map<Object?, Object?>) {
      throw FormatException('$field must be an object.');
    }
    return Map<String, Object?>.from(raw);
  }

  static List<Map<String, Object?>> _maps(Object? raw, String field) {
    if (raw is! List<Object?>) throw FormatException('$field must be a list.');
    return raw.map((Object? value) => _map(value, field)).toList(growable: false);
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) {
    final name = raw?.toString();
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown enum value: $name');
  }
}
