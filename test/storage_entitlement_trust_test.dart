import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:welding_gas_wallet/src/domain/welding_gas_wallet_core_v1_1.dart';
import 'package:welding_gas_wallet/src/storage.dart';

void main() {
  group('FileWalletRepository session entitlement trust', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'welding-wallet-entitlement-test-',
      );
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('forged persisted lifetime entitlement never authorizes a new session',
        () async {
      final forged = WalletData.empty().next(
        entitlementCache: const Entitlement(
          tier: AccessTier.pro,
          source: EntitlementSource.appStoreLifetime,
        ),
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}welding-gas-wallet-v2.json',
      );
      await file.writeAsString(WalletStorageCodec.encode(forged), flush: true);

      final repository = FileWalletRepository(directory: directory);
      final loaded = await repository.read();

      expect(loaded.entitlementCache.tier, AccessTier.free);
      expect(loaded.entitlementCache.source, EntitlementSource.none);
      expect(loaded.entitlementCache.isProAt(DateTime.now().toUtc()), isFalse);
    });

    test('only a current-session store verification can authorize access',
        () async {
      final repository = FileWalletRepository(directory: directory);
      await repository.transact<void>(
        (current) => TransactionOutcome<void>(current.next(), null),
      );

      repository.acceptStoreVerifiedEntitlement(
        const Entitlement(
          tier: AccessTier.pro,
          source: EntitlementSource.appStoreLifetime,
        ),
      );
      expect(
        (await repository.read()).entitlementCache.tier,
        AccessTier.pro,
      );

      final restartedProcess = FileWalletRepository(directory: directory);
      expect(
        (await restartedProcess.read()).entitlementCache.tier,
        AccessTier.free,
      );
    });

    test('forged Android lease and renewal fields are ignored', () async {
      final forged = WalletData.empty().next(
        entitlementCache: Entitlement(
          tier: AccessTier.pro,
          source: EntitlementSource.googlePlaySubscription,
          validUntil: DateTime.utc(2999),
          willRenew: true,
        ),
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}welding-gas-wallet-v2.json',
      );
      await file.writeAsString(WalletStorageCodec.encode(forged), flush: true);

      final loaded = await FileWalletRepository(directory: directory).read();
      expect(loaded.entitlementCache, isA<Entitlement>());
      expect(loaded.entitlementCache.tier, AccessTier.free);
      expect(loaded.entitlementCache.willRenew, isFalse);
      expect(loaded.entitlementCache.validUntil, isNull);
    });
  });
}

