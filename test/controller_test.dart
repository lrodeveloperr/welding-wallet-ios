import 'package:flutter_test/flutter_test.dart';
import 'package:welding_gas_wallet/src/app_controller.dart';
import 'package:welding_gas_wallet/src/domain/welding_gas_wallet_core_v1_1.dart';
import 'package:welding_gas_wallet/src/storage.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bootstrap refreshes native store on launch and resume', () async {
    final harness = ControllerHarness();
    await harness.controller.bootstrap();
    expect(harness.billing.refreshCount, 1);
    await harness.controller.onResumed();
    expect(harness.billing.refreshCount, 2);
  });

  test('notification denial uses catalog copy, never raw exception text', () async {
    final harness = ControllerHarness();
    harness.reminders.permissionGranted = false;
    await harness.controller.bootstrap();
    await harness.controller.setRemindersEnabled(true);
    expect(
      harness.controller.errorMessage,
      harness.controller.t('notificationPermissionDenied'),
    );
    expect(harness.controller.errorMessage, isNot(contains('StateError')));
  });

  test('link failure uses catalog copy', () async {
    final links = TestLinkGateway()..fail = true;
    final harness = ControllerHarness(links: links);
    await harness.controller.bootstrap();
    await harness.controller.openLegal(LegalLinks.privacy);
    expect(harness.controller.errorMessage, harness.controller.t('linkUnavailable'));
  });

  test('invalid value, backup and conflict errors are localized', () async {
    final harness = ControllerHarness();
    await harness.controller.bootstrap();

    await harness.controller.updateSettings(currencyCode: 'ZZZ');
    expect(harness.controller.errorMessage, harness.controller.t('invalidValue'));

    await harness.controller.run<void>(() async {
      throw const FormatException('private parser detail');
    });
    expect(harness.controller.errorMessage, harness.controller.t('invalidBackup'));

    await harness.controller.run<void>(() async {
      throw const WalletConflictException(1, 2);
    });
    expect(harness.controller.errorMessage, harness.controller.t('walletChanged'));
  });

  test('store failure grants nothing and retains a preserved draft', () async {
    final harness = ControllerHarness(storeFails: true);
    await harness.controller.bootstrap();
    for (var index = 0; index < 4; index++) {
      await harness.controller.addCylinder(AddCylinderDraft(
        nickname: 'C$index',
        gasType: 'Argon',
        relationship: RelationshipType.owned,
      ));
    }
    expect(harness.controller.data!.cylinders, hasLength(3));
    expect(harness.controller.data!.pendingDraft, isNotNull);
    expect(harness.controller.isPro, isFalse);
    await harness.controller.refreshStoreAccess();
    expect(harness.controller.isPro, isFalse);
    expect(harness.controller.data!.pendingDraft, isNotNull);
  });

  test('initiated non-success purchase states are localized fail-closed',
      () async {
    final expectedKeys = <PurchaseOutcome, String>{
      PurchaseOutcome.pending: 'purchasePending',
      PurchaseOutcome.cancelled: 'purchaseCancelled',
      PurchaseOutcome.failed: 'purchaseFailed',
      PurchaseOutcome.unverified: 'purchaseFailed',
    };
    for (final entry in expectedKeys.entries) {
      final harness = ControllerHarness();
      await harness.controller.bootstrap();
      for (var index = 0; index < 4; index++) {
        await harness.controller.addCylinder(AddCylinderDraft(
          nickname: 'C$index',
          gasType: 'Argon',
          relationship: RelationshipType.owned,
        ));
      }
      harness.billing.purchaseOutcome = entry.key;

      await harness.controller.purchase(ProductIds.androidAnnual);

      expect(harness.controller.isPro, isFalse, reason: entry.key.name);
      expect(harness.controller.data!.pendingDraft, isNotNull);
      expect(
        harness.controller.errorMessage,
        harness.controller.t(entry.value),
        reason: entry.key.name,
      );
      expect(harness.controller.noticeMessage, isNull);
    }
  });

  test('explicit empty restore reports not found instead of restored', () async {
    final harness = ControllerHarness();
    await harness.controller.bootstrap();

    await harness.controller.restore();

    expect(harness.controller.isPro, isFalse);
    expect(
      harness.controller.errorMessage,
      harness.controller.t('purchaseNotFound'),
    );
    expect(harness.controller.noticeMessage, isNull);
  });

  test('verified purchase explicitly confirms and resumes the draft', () async {
    final harness = ControllerHarness();
    await harness.controller.bootstrap();
    for (var index = 0; index < 4; index++) {
      await harness.controller.addCylinder(AddCylinderDraft(
        nickname: 'C$index',
        gasType: 'Argon',
        relationship: RelationshipType.owned,
      ));
    }
    harness.billing.entitlement = Entitlement(
      tier: AccessTier.pro,
      source: EntitlementSource.googlePlaySubscription,
      validUntil: harness.clock.now().add(const Duration(hours: 24)),
      willRenew: true,
    );

    await harness.controller.purchase(ProductIds.androidAnnual);

    expect(harness.controller.isPro, isTrue);
    expect(harness.controller.data!.pendingDraft, isNull);
    expect(harness.controller.data!.cylinders, hasLength(4));
    expect(
      harness.controller.noticeMessage,
      harness.controller.t('purchaseActivated'),
    );
    expect(harness.controller.errorMessage, isNull);
  });

  test('pending purchase activates automatically when verified in foreground',
      () async {
    final harness = ControllerHarness();
    addTearDown(() async {
      harness.controller.dispose();
      await harness.billing.dispose();
    });
    await harness.controller.bootstrap();
    for (var index = 0; index < 4; index++) {
      await harness.controller.addCylinder(AddCylinderDraft(
        nickname: 'C$index',
        gasType: 'Argon',
        relationship: RelationshipType.owned,
      ));
    }
    harness.billing.purchaseOutcome = PurchaseOutcome.pending;
    await harness.controller.purchase(ProductIds.androidAnnual);
    expect(harness.controller.isPro, isFalse);
    expect(harness.controller.data!.pendingDraft, isNotNull);
    expect(
      harness.controller.errorMessage,
      harness.controller.t('purchasePending'),
    );

    harness.billing
      ..purchaseOutcome = null
      ..entitlement = Entitlement(
        tier: AccessTier.pro,
        source: EntitlementSource.googlePlaySubscription,
        validUntil: harness.clock.now().add(const Duration(hours: 24)),
        willRenew: true,
      )
      ..emitEntitlementUpdate();
    await pumpEventQueue(times: 20);

    expect(harness.controller.isPro, isTrue);
    expect(harness.controller.data!.pendingDraft, isNull);
    expect(harness.controller.data!.cylinders, hasLength(4));
    expect(
      harness.controller.noticeMessage,
      harness.controller.t('purchaseActivated'),
    );
    expect(harness.controller.errorMessage, isNull);
  });

  test('exact legal URLs remain wired', () {
    expect(LegalLinks.privacy.toString(),
        'https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/privacy/');
    expect(LegalLinks.terms.toString(),
        'https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/terms/');
    expect(LegalLinks.support.toString(),
        'https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/support/');
    expect(LegalLinks.deletion.toString(),
        'https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/deletion/');
    expect(LegalLinks.disclaimer.toString(),
        'https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/disclaimer/');
  });
}

class ControllerHarness {
  ControllerHarness({TestLinkGateway? links, bool storeFails = false})
      : repo = MemoryWalletRepository(_onboardedSeed()),
        clock = TestClock(),
        reminders = TestReminderGateway(),
        billing = TestBillingGateway(fail: storeFails) {
    engine = WeldingGasWalletEngine(
      repo: repo,
      billing: billing,
      scheduler: reminders,
      ids: SequenceIds(),
      clock: clock,
    );
    controller = WalletController(
      engine: engine,
      billing: billing,
      reminderPermission: reminders,
      initialLocale: 'en',
      links: links ?? TestLinkGateway(),
    );
  }

  final MemoryWalletRepository repo;
  final TestClock clock;
  final TestReminderGateway reminders;
  final TestBillingGateway billing;
  late final WeldingGasWalletEngine engine;
  late final WalletController controller;
}

WalletData _onboardedSeed() {
  final empty = WalletData.empty();
  return empty.next(
    settings: empty.settings.copyWith(onboardingComplete: true),
  );
}
