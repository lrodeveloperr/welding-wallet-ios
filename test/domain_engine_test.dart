import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:welding_gas_wallet/src/domain/welding_gas_wallet_core_v1_1.dart';
import 'package:welding_gas_wallet/src/storage.dart';

import 'support/fakes.dart';

void main() {
  group('free limit and purchase flow', () {
    test('first three current cylinders are free and fourth draft is preserved',
        () async {
      final harness = Harness();
      for (var index = 1; index <= 3; index++) {
        final result = await harness.engine.addOrGate(_draft(index));
        expect(result, isA<CylinderAdded>());
      }

      final fourth = await harness.engine.addOrGate(_draft(4));
      expect(fourth, isA<AddRequiresPaywall>());
      final state = await harness.repo.read();
      expect(state.cylinders, hasLength(3));
      expect(state.pendingDraft?.nickname, 'Cylinder 4');
      expect(
        state.cylinders.where((item) => item.isFreeEditableSelection),
        hasLength(3),
      );
    });

    test('verified purchase inserts the preserved draft exactly once', () async {
      final harness = Harness(
        entitlement: Entitlement(
          tier: AccessTier.pro,
          source: EntitlementSource.googlePlaySubscription,
          validUntil: DateTime.utc(2026, 8, 22),
          willRenew: true,
        ),
      );
      for (var index = 1; index <= 4; index++) {
        await harness.engine.addOrGate(_draft(index));
      }

      final resumed = await harness.engine.purchaseAndResume(
        ProductIds.androidAnnual,
      );
      expect(resumed?.nickname, 'Cylinder 4');
      expect((await harness.repo.read()).cylinders, hasLength(4));
      expect((await harness.repo.read()).pendingDraft, isNull);

      await harness.engine.restoreAndResume();
      expect((await harness.repo.read()).cylinders, hasLength(4));
    });

    test('wrong-platform entitlement source never grants access', () async {
      final harness = Harness(
        entitlement: const Entitlement(
          tier: AccessTier.pro,
          source: EntitlementSource.appStoreLifetime,
        ),
      );
      await expectLater(
        harness.engine.purchaseAndResume(ProductIds.androidAnnual),
        throwsStateError,
      );
      expect((await harness.repo.read()).entitlementCache.tier, AccessTier.free);
    });

    test('free downgrade requires an explicit editable selection', () async {
      final now = DateTime.utc(2026, 8, 21, 12);
      final cylinders = List<Cylinder>.generate(
        4,
        (index) => Cylinder(
          id: 'c$index',
          nickname: 'C$index',
          gasType: 'Oxygen',
          relationship: RelationshipType.owned,
          lifecycle: CylinderLifecycle.active,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final seed = WalletData.empty().next(cylinders: cylinders);
      final harness = Harness(seed: seed);
      final decision = await harness.engine.enforceDowngradeIfNeeded();
      expect(decision, isA<RequiresFreeSelection>());

      await harness.engine.selectFreeEditable(<String>{'c0', 'c1', 'c2'});
      final state = await harness.repo.read();
      expect(
        state.cylinders.where((item) => item.isFreeEditableSelection),
        hasLength(3),
      );
      expect(await harness.engine.canEditCylinder('c3'), isA<Locked>());
    });
  });

  group('records, money and reminders', () {
    test('cylinder details, relationship and supplier update atomically', () async {
      final harness = Harness();
      final added = await harness.engine.addOrGate(_draft(1)) as CylinderAdded;
      final before = await harness.repo.read();

      await expectLater(
        harness.engine.updateCylinderDetails(
          cylinderId: added.cylinder.id,
          nickname: 'Must not stick',
          relationship: RelationshipType.leased,
          supplierId: const SetValue<String>('missing-supplier'),
          expectedRevision: before.revision,
        ),
        throwsArgumentError,
      );
      final after = await harness.repo.read();
      expect(after.revision, before.revision);
      expect(after.cylinders.single.nickname, 'Cylinder 1');
      expect(after.cylinders.single.relationship, RelationshipType.owned);
      expect(after.cylinders.single.supplierId, isNull);
      expect(after.events, hasLength(before.events.length));
    });

    test('editing or clearing acquisition keeps cylinder, Activity and Spend aligned',
        () async {
      final harness = Harness();
      final added = await harness.engine.addOrGate(AddCylinderDraft(
        nickname: 'Deposit bottle',
        gasType: 'Argon',
        relationship: RelationshipType.deposit,
        acquisitionAmount: Money(minorUnits: 10000, currencyCode: 'USD'),
        acquiredAt: DateTime.utc(2026, 1, 5),
      )) as CylinderAdded;
      expect(await harness.engine.spendByCurrency(), <String, int>{'USD': 10000});

      await harness.engine.updateCylinderDetails(
        cylinderId: added.cylinder.id,
        acquisitionAmount: SetValue<Money>(
          Money(minorUnits: 12500, currencyCode: 'USD'),
        ),
        acquiredAt: SetValue<DateTime>(DateTime.utc(2026, 2, 6)),
      );
      var state = await harness.repo.read();
      var acquisition = state.events.singleWhere(
        (event) => event.type == CylinderEventType.created,
      );
      expect(state.cylinders.single.acquisitionAmount?.minorUnits, 12500);
      expect(acquisition.amount?.minorUnits, 12500);
      expect(acquisition.occurredAt, DateTime.utc(2026, 2, 6));
      expect(await harness.engine.spendByCurrency(), <String, int>{'USD': 12500});

      await harness.engine.updateCylinderDetails(
        cylinderId: added.cylinder.id,
        acquisitionAmount: const Clear<Money>(),
        acquiredAt: const Clear<DateTime>(),
      );
      state = await harness.repo.read();
      acquisition = state.events.singleWhere(
        (event) => event.type == CylinderEventType.created,
      );
      expect(state.cylinders.single.acquisitionAmount, isNull);
      expect(acquisition.amount, isNull);
      expect(acquisition.occurredAt, state.cylinders.single.createdAt);
      expect(await harness.engine.spendByCurrency(), isEmpty);
    });

    test('refill, exchange and cost preserve exact currencies', () async {
      final harness = Harness();
      final added = await harness.engine.addOrGate(_draft(1)) as CylinderAdded;
      await harness.engine.recordRefill(
        cylinderId: added.cylinder.id,
        occurredAt: harness.clock.now(),
        amount: Money(minorUnits: 1234, currencyCode: 'EUR'),
      );
      await harness.engine.recordExchange(
        cylinderId: added.cylinder.id,
        occurredAt: harness.clock.now(),
        amount: Money(minorUnits: 2200, currencyCode: 'USD'),
        newSerialNumber: const SetValue<String>('NEW-7'),
      );
      await harness.engine.recordCost(
        cylinderId: added.cylinder.id,
        occurredAt: harness.clock.now(),
        amount: Money(minorUnits: 66, currencyCode: 'EUR'),
      );

      expect(
        await harness.engine.spendByCurrency(),
        <String, int>{'EUR': 1300, 'USD': 2200},
      );
      final cylinder = (await harness.repo.read()).cylinders.single;
      expect(cylinder.serialNumber, 'NEW-7');
      expect(cylinder.lifecycle, CylinderLifecycle.exchanged);
    });

    test('returned deposit reduces net outlay and never converts currency',
        () async {
      final now = DateTime.utc(2026, 8, 21);
      final seed = WalletData.empty().next(
        events: <CylinderEvent>[
          CylinderEvent(
            id: 'paid',
            cylinderId: 'c',
            type: CylinderEventType.depositPaid,
            occurredAt: now,
            amount: Money(minorUnits: 10000, currencyCode: 'USD'),
          ),
          CylinderEvent(
            id: 'returned',
            cylinderId: 'c',
            type: CylinderEventType.depositReturned,
            occurredAt: now,
            amount: Money(minorUnits: 4000, currencyCode: 'USD'),
          ),
          CylinderEvent(
            id: 'eur',
            cylinderId: 'c',
            type: CylinderEventType.cost,
            occurredAt: now,
            amount: Money(minorUnits: 700, currencyCode: 'EUR'),
          ),
        ],
      );
      final harness = Harness(seed: seed);
      expect(
        await harness.engine.spendByCurrency(),
        <String, int>{'USD': 6000, 'EUR': 700},
      );
    });

    test('notification failure leaves a durable reconciliation marker', () async {
      final harness = Harness();
      final added = await harness.engine.addOrGate(_draft(1)) as CylinderAdded;
      await harness.engine.setRemindersEnabled(true);
      harness.scheduler.failScheduling = true;
      final result = await harness.engine.createReminder(
        cylinderId: added.cylinder.id,
        kind: ReminderKind.refill,
        title: 'Refill',
        dueAt: harness.clock.now().add(const Duration(days: 2)),
      );
      expect(result.systemScheduleConfirmed, isFalse);
      expect(
        (await harness.repo.read()).reminders.single.delivery,
        ReminderDelivery.needsScheduling,
      );

      harness.scheduler.failScheduling = false;
      await harness.engine.reconcileReminders();
      expect(
        (await harness.repo.read()).reminders.single.delivery,
        ReminderDelivery.scheduled,
      );
    });
  });

  group('deletion integrity', () {
    test('deletes cylinder, its events and reminders after cancellation', () async {
      final harness = Harness();
      final first = await harness.engine.addOrGate(_draft(1)) as CylinderAdded;
      await harness.engine.addOrGate(_draft(2));
      await harness.engine.createReminder(
        cylinderId: first.cylinder.id,
        kind: ReminderKind.check,
        title: 'Check',
        dueAt: harness.clock.now().add(const Duration(days: 1)),
      );

      await harness.engine.deleteCylinder(first.cylinder.id, confirmed: true);
      final state = await harness.repo.read();
      expect(state.cylinders.map((item) => item.id), isNot(contains(first.cylinder.id)));
      expect(state.events.where((item) => item.cylinderId == first.cylinder.id), isEmpty);
      expect(
        state.reminders.where((item) => item.cylinderId == first.cylinder.id),
        isEmpty,
      );
    });

    test('cancellation failure retains the complete recoverable record', () async {
      final harness = Harness();
      final added = await harness.engine.addOrGate(_draft(1)) as CylinderAdded;
      await harness.engine.createReminder(
        cylinderId: added.cylinder.id,
        kind: ReminderKind.custom,
        title: 'Keep',
        dueAt: harness.clock.now().add(const Duration(days: 1)),
      );
      harness.scheduler.failCancellation = true;

      await expectLater(
        harness.engine.deleteCylinder(added.cylinder.id, confirmed: true),
        throwsStateError,
      );
      final state = await harness.repo.read();
      expect(state.cylinders, hasLength(1));
      expect(state.events, isNotEmpty);
      expect(state.reminders, hasLength(1));
    });

    test('explicit confirmation is mandatory', () async {
      final harness = Harness();
      final added = await harness.engine.addOrGate(_draft(1)) as CylinderAdded;
      await expectLater(
        harness.engine.deleteCylinder(added.cylinder.id, confirmed: false),
        throwsStateError,
      );
      expect((await harness.repo.read()).cylinders, hasLength(1));
    });
  });

  group('backup, conflicts and validation', () {
    test('backup round-trip excludes entitlement and local photo URI', () async {
      final harness = Harness();
      await harness.engine.addOrGate(AddCylinderDraft(
        nickname: 'Photo cylinder',
        gasType: 'Argon',
        relationship: RelationshipType.rented,
        localPhotoUri: '/private/photo.jpg',
      ));
      final encoded = await harness.engine.exportBackup();
      final decoded = BackupCodec.decode(encoded);
      expect(decoded.cylinders.single.localPhotoUri, isNull);
      expect(decoded.entitlementCache.tier, AccessTier.free);
    });

    test('tampered backup fails before replacing data', () async {
      final harness = Harness();
      await harness.engine.addOrGate(_draft(1));
      final before = await harness.repo.read();
      final encoded = await harness.engine.exportBackup();
      final tampered = encoded.replaceFirst('Cylinder 1', 'Cylinder X');
      await expectLater(
        harness.engine.importBackup(tampered, expectedRevision: before.revision),
        throwsFormatException,
      );
      expect((await harness.repo.read()).cylinders.single.nickname, 'Cylinder 1');
    });

    test('stale expected revision is rejected atomically', () async {
      final harness = Harness();
      final revision = (await harness.repo.read()).revision;
      await harness.engine.addOrGate(_draft(1), expectedRevision: revision);
      await expectLater(
        harness.engine.addOrGate(_draft(2), expectedRevision: revision),
        throwsA(isA<WalletConflictException>()),
      );
      expect((await harness.repo.read()).cylinders, hasLength(1));
    });

    test('repository serializes a burst of concurrent mutations', () async {
      final repo = MemoryWalletRepository();
      await Future.wait(List<Future<void>>.generate(50, (index) async {
        await repo.transact<void>((current) => TransactionOutcome<void>(
              current.next(settings: current.settings.copyWith(
                onboardingComplete: index.isEven,
              )),
              null,
            ));
      }));
      expect((await repo.read()).revision, 50);
    });

    test('locale and currency inputs are canonical and bounded', () {
      expect(canonicalLocale('ZH_cn'), 'zh-Hans');
      expect(canonicalLocale('pt-BR'), 'pt');
      expect(canonicalLocale('unknown'), 'en');
      expect(normalizedCurrency('eur'), 'EUR');
      expect(() => Money(minorUnits: 1, currencyCode: 'ZZZ'), throwsArgumentError);
    });
  });
}

AddCylinderDraft _draft(int index) => AddCylinderDraft(
      nickname: 'Cylinder $index',
      gasType: index.isEven ? 'Argon' : 'Oxygen',
      relationship: RelationshipType.owned,
      capacityValue: 20,
      capacityUnit: 'L',
    );

class Harness {
  Harness({
    WalletData? seed,
    Entitlement entitlement = const Entitlement.free(),
  })  : repo = MemoryWalletRepository(seed),
        clock = TestClock(),
        scheduler = TestReminderGateway(),
        billing = TestBillingGateway(entitlement: entitlement) {
    engine = WeldingGasWalletEngine(
      repo: repo,
      billing: billing,
      scheduler: scheduler,
      ids: SequenceIds(),
      clock: clock,
    );
  }

  final MemoryWalletRepository repo;
  final TestClock clock;
  final TestReminderGateway scheduler;
  final TestBillingGateway billing;
  late final WeldingGasWalletEngine engine;
}
