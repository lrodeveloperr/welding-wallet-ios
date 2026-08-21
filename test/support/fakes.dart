import 'dart:async';

import 'package:welding_gas_wallet/src/app_controller.dart';
import 'package:welding_gas_wallet/src/domain/welding_gas_wallet_core_v1_1.dart';
import 'package:welding_gas_wallet/src/reminders.dart';

class TestClock implements Clock {
  TestClock([DateTime? value])
      : value = value ?? DateTime.utc(2026, 8, 21, 12);

  DateTime value;

  @override
  DateTime now() => value;
}

class SequenceIds implements IdFactory {
  int _value = 0;

  @override
  String newId() => 'test-${++_value}';
}

class TestReminderGateway
    implements ReminderScheduler, ReminderPermissionGateway {
  bool permissionGranted = true;
  bool failScheduling = false;
  bool failCancellation = false;
  final Set<String> scheduled = <String>{};

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> schedule(Reminder reminder) async {
    if (failScheduling) throw StateError('schedule failed');
    scheduled.add(reminder.id);
  }

  @override
  Future<void> cancel(String reminderId) async {
    if (failCancellation) throw StateError('cancel failed');
    scheduled.remove(reminderId);
  }

  @override
  Future<void> cancelAll() async {
    if (failCancellation) throw StateError('cancel failed');
    scheduled.clear();
  }
}

/// Test-only store gateway. Nothing under lib/ can instantiate this class.
class TestBillingGateway
    implements StoreBillingGateway, StoreEntitlementUpdateGateway {
  TestBillingGateway({
    this.platform = StorePlatform.android,
    this.entitlement = const Entitlement.free(),
    this.fail = false,
  });

  @override
  final StorePlatform platform;
  Entitlement entitlement;
  bool fail;
  PurchaseOutcome? purchaseOutcome;
  int refreshCount = 0;
  String? purchasedProduct;
  bool openedManagement = false;
  final StreamController<void> _entitlementUpdates =
      StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get entitlementRefreshRequests => _entitlementUpdates.stream;

  void emitEntitlementUpdate() => _entitlementUpdates.add(null);

  Future<void> dispose() => _entitlementUpdates.close();

  @override
  Future<List<StoreProduct>> loadProducts() async {
    if (fail) throw StateError('store unavailable');
    return platform == StorePlatform.android
        ? const <StoreProduct>[
            StoreProduct(
              id: ProductIds.androidAnnual,
              localizedPrice: '€11.99',
              localizedPeriodLabel: 'year',
              isDefault: true,
            ),
            StoreProduct(
              id: ProductIds.androidMonthly,
              localizedPrice: '€1.79',
              localizedPeriodLabel: 'month',
              isDefault: false,
            ),
          ]
        : const <StoreProduct>[
            StoreProduct(
              id: ProductIds.iosLifetime,
              localizedPrice: '€19.99',
              localizedPeriodLabel: 'lifetime',
              isDefault: true,
            ),
          ];
  }

  @override
  Future<Entitlement> purchaseVerified(String productId) async {
    if (fail) throw StateError('purchase failed');
    if (purchaseOutcome case final outcome?) {
      throw PurchaseOutcomeException(outcome);
    }
    purchasedProduct = productId;
    return entitlement;
  }

  @override
  Future<Entitlement> restoreOrRefreshVerified() async {
    refreshCount++;
    if (fail) throw StateError('refresh failed');
    return entitlement;
  }

  @override
  Future<void> openSubscriptionManagement() async {
    openedManagement = true;
  }
}

class TestLinkGateway implements ExternalLinkGateway {
  Uri? opened;
  bool fail = false;

  @override
  Future<void> open(Uri uri) async {
    if (fail) throw const ControllerUserException('linkUnavailable');
    opened = uri;
  }
}
