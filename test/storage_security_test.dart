import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:welding_gas_wallet/src/domain/welding_gas_wallet_core_v1_1.dart';
import 'package:welding_gas_wallet/src/storage.dart';

import 'support/fakes.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('welding-wallet-test-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('atomic file repository persists complete revisions', () async {
    final repo = FileWalletRepository(directory: directory, initialLocale: 'de');
    expect((await repo.read()).settings.locale, 'de');

    await repo.transact<void>((current) => TransactionOutcome<void>(
          current.next(
            settings: current.settings.copyWith(onboardingComplete: true),
          ),
          null,
        ));
    final reopened = FileWalletRepository(directory: directory);
    final state = await reopened.read();
    expect(state.revision, 1);
    expect(state.settings.onboardingComplete, isTrue);
  });

  test('serialized concurrent file mutations lose no revisions', () async {
    final repo = FileWalletRepository(directory: directory);
    await Future.wait(List<Future<void>>.generate(40, (index) async {
      await repo.transact<void>((current) => TransactionOutcome<void>(
            current.next(
              settings: current.settings.copyWith(
                defaultMassUnit: index.isEven ? 'kg' : 'lb',
              ),
            ),
            null,
          ));
    }));
    expect((await repo.read()).revision, 40);
  });

  test('corrupt current file is quarantined and never overwritten', () async {
    final file = File('${directory.path}/welding-gas-wallet-v2.json');
    await file.writeAsString('{not valid json');
    final repo = FileWalletRepository(directory: directory);
    await expectLater(repo.read(), throwsA(isA<StorageCorruptionException>()));
    expect(await file.exists(), isFalse);
    expect(
      directory
          .listSync()
          .whereType<File>()
          .where((item) => item.path.contains('.corrupt.')),
      hasLength(1),
    );
    // Retry remains fail-closed; it must not substitute a new empty wallet.
    await expectLater(repo.read(), throwsA(isA<StorageCorruptionException>()));
    expect(await file.exists(), isFalse);
  });

  test('explicit clear resolves a corruption marker and removes quarantine',
      () async {
    final file = File('${directory.path}/welding-gas-wallet-v2.json');
    await file.writeAsString('{broken');
    final repo = FileWalletRepository(directory: directory, initialLocale: 'es');
    await expectLater(repo.read(), throwsA(isA<StorageCorruptionException>()));

    final cleared = await repo.clearCorruptStore(confirmed: true);
    expect(cleared.settings.locale, 'es');
    expect((await repo.read()).cylinders, isEmpty);
    final names = directory
        .listSync()
        .map((entity) => entity.path.split(Platform.pathSeparator).last)
        .toList();
    expect(names, <String>['welding-gas-wallet-v2.json']);
  });

  test('interrupted rotation restores the previous complete file', () async {
    final previous = File(
      '${directory.path}/welding-gas-wallet-v2.json.previous',
    );
    final seed = WalletData.empty(locale: 'fr').next(
      settings: WalletData.empty(locale: 'fr')
          .settings
          .copyWith(onboardingComplete: true),
    );
    await previous.writeAsString(WalletStorageCodec.encode(seed));
    final repo = FileWalletRepository(directory: directory);
    final restored = await repo.read();
    expect(restored.settings.locale, 'fr');
    expect(restored.settings.onboardingComplete, isTrue);
    expect(await previous.exists(), isFalse);
  });

  test('forged persisted Pro is ignored until native verification this session',
      () async {
    final forged = WalletData(
      schemaVersion: walletSchemaVersion,
      revision: 7,
      settings: WalletData.empty().settings,
      suppliers: const <Supplier>[],
      cylinders: const <Cylinder>[],
      events: const <CylinderEvent>[],
      reminders: const <Reminder>[],
      pendingDraft: null,
      entitlementCache: Entitlement(
        tier: AccessTier.pro,
        source: EntitlementSource.googlePlaySubscription,
        validUntil: DateTime.utc(2099),
        willRenew: true,
      ),
    );
    final file = File('${directory.path}/welding-gas-wallet-v2.json');
    await file.writeAsString(WalletStorageCodec.encode(forged));

    final repo = FileWalletRepository(directory: directory);
    expect((await repo.read()).entitlementCache.tier, AccessTier.free);

    final verified = Entitlement(
      tier: AccessTier.pro,
      source: EntitlementSource.googlePlaySubscription,
      validUntil: DateTime.utc(2026, 8, 22),
      willRenew: true,
    );
    final billing = TestBillingGateway(entitlement: verified);
    final engine = WeldingGasWalletEngine(
      repo: repo,
      billing: billing,
      scheduler: TestReminderGateway(),
      ids: SequenceIds(),
      clock: TestClock(),
    );
    await engine.restoreAndResume();
    expect((await repo.read()).entitlementCache.tier, AccessTier.pro);

    // A new process/repository has no store proof and fails closed again.
    final restarted = FileWalletRepository(directory: directory);
    expect((await restarted.read()).entitlementCache.tier, AccessTier.free);
  });

  test('backup replacement never imports a forged entitlement', () async {
    final repo = FileWalletRepository(directory: directory);
    final current = await repo.read();
    final imported = WalletData(
      schemaVersion: walletSchemaVersion,
      revision: 99,
      settings: current.settings,
      suppliers: const <Supplier>[],
      cylinders: const <Cylinder>[],
      events: const <CylinderEvent>[],
      reminders: const <Reminder>[],
      pendingDraft: null,
      entitlementCache: const Entitlement(
        tier: AccessTier.pro,
        source: EntitlementSource.appStoreLifetime,
      ),
    );
    await repo.replaceFromBackup(imported, expectedRevision: current.revision);
    expect((await repo.read()).entitlementCache.tier, AccessTier.free);
  });

  test('Delete all purges every app-managed residual wallet copy', () async {
    final repo = FileWalletRepository(directory: directory);
    final billing = TestBillingGateway();
    final engine = WeldingGasWalletEngine(
      repo: repo,
      billing: billing,
      scheduler: TestReminderGateway(),
      ids: SequenceIds(),
      clock: TestClock(),
    );
    await engine.addOrGate(const AddCylinderDraft(
      nickname: 'Private cylinder',
      gasType: 'Oxygen',
      relationship: RelationshipType.owned,
    ));
    final base = '${directory.path}/welding-gas-wallet-v2.json';
    await File('$base.previous').writeAsString('private previous');
    await File('$base.recovery').writeAsString('private recovery');
    await File('$base.tmp').writeAsString('private temp');
    await File('$base.corrupt.old').writeAsString('private quarantine');

    await engine.deleteAllWalletData(confirmed: true);
    final state = await repo.read();
    expect(state.cylinders, isEmpty);
    expect(state.events, isEmpty);
    final names = directory
        .listSync()
        .map((entity) => entity.path.split(Platform.pathSeparator).last)
        .toList();
    expect(names, <String>['welding-gas-wallet-v2.json']);
    expect(await File(base).readAsString(), isNot(contains('Private cylinder')));
  });
}
