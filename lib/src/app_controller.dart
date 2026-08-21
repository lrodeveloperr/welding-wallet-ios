import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'app_strings.dart';
import 'backup_files.dart';
import 'domain/welding_gas_wallet_core_v1_1.dart';
import 'reminders.dart';

abstract final class LegalLinks {
  static final privacy = Uri.parse(
    'https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/privacy/',
  );
  static final terms = Uri.parse(
    'https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/terms/',
  );
  static final support = Uri.parse(
    'https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/support/',
  );
  static final deletion = Uri.parse(
    'https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/deletion/',
  );
  static final disclaimer = Uri.parse(
    'https://lrodeveloperr.github.io/privacy-policy/welding-gas-wallet/disclaimer/',
  );
}

abstract interface class ExternalLinkGateway {
  Future<void> open(Uri uri);
}

class DeviceExternalLinkGateway implements ExternalLinkGateway {
  const DeviceExternalLinkGateway();

  @override
  Future<void> open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const ControllerUserException('linkUnavailable');
    }
  }
}

class ControllerUserException implements Exception {
  const ControllerUserException(this.localizationKey);

  final String localizationKey;
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

class UuidIdFactory implements IdFactory {
  UuidIdFactory({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String newId() => _uuid.v7();
}

class WalletController extends ChangeNotifier {
  WalletController({
    required this.engine,
    required this.billing,
    required this.reminderPermission,
    required String initialLocale,
    BackupFiles backupFiles = const BackupFiles(),
    ExternalLinkGateway links = const DeviceExternalLinkGateway(),
  })  : _backupFiles = backupFiles,
        _initialLocale = canonicalLocale(initialLocale),
        _links = links {
    if (billing case StoreEntitlementUpdateGateway updates) {
      _storeUpdateSubscription = updates.entitlementRefreshRequests.listen(
        (_) => _queueStoreReconciliation(),
      );
    }
  }

  final WeldingGasWalletEngine engine;
  final StoreBillingGateway billing;
  final ReminderPermissionGateway reminderPermission;
  final BackupFiles _backupFiles;
  final ExternalLinkGateway _links;
  final String _initialLocale;
  StreamSubscription<void>? _storeUpdateSubscription;
  bool _storeReconciliationQueued = false;
  bool _drainingStoreReconciliation = false;

  WalletData? data;
  AppStrings? strings;
  List<StoreProduct> products = const <StoreProduct>[];
  Object? startupError;
  LocalizationCatalogException? localizationFailure;
  String? errorMessage;
  String? noticeMessage;
  String? storeStatusMessage;
  bool booting = true;
  bool busy = false;
  bool refreshingStore = false;

  bool get ready => data != null && strings != null && startupError == null;

  bool get isPro =>
      data?.entitlementCache.isProAt(DateTime.now().toUtc()) ?? false;

  List<Cylinder> get currentCylinders => data?.cylinders
          .where((cylinder) => cylinder.consumesCurrentSlot)
          .toList(growable: false) ??
      const <Cylinder>[];

  String t(
    String key, [
    Map<String, Object?> values = const <String, Object?>{},
  ]) =>
      strings?.call(key, values) ?? key;

  Future<void> bootstrap() async {
    booting = true;
    startupError = null;
    localizationFailure = null;
    notifyListeners();
    try {
      try {
        strings ??= await AppStrings.load(_initialLocale);
      } on LocalizationCatalogException catch (error) {
        localizationFailure = error;
        return;
      }
      data = await engine.snapshot();
      try {
        if (strings!.locale != data!.settings.locale) {
          strings = await AppStrings.load(data!.settings.locale);
        }
        if (reminderPermission case ReminderPresentationGateway presentation) {
          presentation.configureLocalizedPresentation(
            channelName: t('reminders'),
            channelDescription: t('remindersBody'),
          );
        }
      } on LocalizationCatalogException catch (error) {
        localizationFailure = error;
        return;
      }
      booting = false;
      notifyListeners();
      await _refreshProducts();
      await refreshStoreAccess(silent: true);
      await engine.enforceDowngradeIfNeeded();
      await engine.reconcileReminders();
      await _refreshSnapshot();
    } on Object catch (error) {
      startupError = error;
    } finally {
      booting = false;
      notifyListeners();
      unawaited(_drainStoreReconciliation());
    }
  }

  void _queueStoreReconciliation() {
    _storeReconciliationQueued = true;
    unawaited(_drainStoreReconciliation());
  }

  Future<void> _drainStoreReconciliation() async {
    if (_drainingStoreReconciliation ||
        booting ||
        !ready ||
        busy ||
        refreshingStore) {
      return;
    }
    _drainingStoreReconciliation = true;
    try {
      while (_storeReconciliationQueued &&
          !booting &&
          ready &&
          !busy &&
          !refreshingStore) {
        _storeReconciliationQueued = false;
        final pendingMessage = t('purchasePending');
        final wasPendingPurchase = errorMessage == pendingMessage;
        await refreshStoreAccess(silent: true);
        if (isPro) {
          errorMessage = null;
          noticeMessage = t('purchaseActivated');
          notifyListeners();
        } else if (wasPendingPurchase) {
          errorMessage = t('purchaseFailed');
          notifyListeners();
        }
      }
    } finally {
      _drainingStoreReconciliation = false;
    }
  }

  Future<void> onResumed() async {
    if (!ready || refreshingStore) return;
    await refreshStoreAccess(silent: true);
    try {
      await engine.reconcileReminders();
      await _refreshSnapshot();
    } on Object {
      // Durable reminder delivery state remains pending for a later resume.
    }
  }

  void clearMessages() {
    errorMessage = null;
    noticeMessage = null;
    notifyListeners();
  }

  Future<void> _refreshProducts() async {
    try {
      products = await engine.getPaywallProducts();
      storeStatusMessage = products.isEmpty ? t('storePriceUnavailable') : null;
    } on Object {
      products = const <StoreProduct>[];
      storeStatusMessage = data?.pendingDraft == null
          ? t('storePriceUnavailable')
          : t('purchaseUnavailable');
    }
    notifyListeners();
  }

  Future<void> reloadProducts() => _refreshProducts();

  Future<void> refreshStoreAccess({bool silent = false}) async {
    if (refreshingStore) return;
    refreshingStore = true;
    if (!silent) {
      errorMessage = null;
      noticeMessage = null;
      notifyListeners();
    }
    try {
      await engine.restoreAndResume();
      await _refreshSnapshot();
      storeStatusMessage = null;
      if (!silent) {
        if (isPro) {
          noticeMessage = t('purchaseRestored');
        } else {
          errorMessage = t('purchaseNotFound');
        }
      }
    } on PurchaseOutcomeException catch (error) {
      if (!silent) errorMessage = _purchaseOutcomeMessage(error.outcome);
      storeStatusMessage = data?.pendingDraft == null
          ? t('storePriceUnavailable')
          : t('purchaseUnavailable');
    } on Object {
      // A failed or unavailable store refresh never destroys a still-valid,
      // previously verified continuity lease and never grants new access.
      storeStatusMessage = data?.pendingDraft == null
          ? t('storePriceUnavailable')
          : t('purchaseUnavailable');
      if (!silent) errorMessage = t('purchaseFailed');
    } finally {
      refreshingStore = false;
      notifyListeners();
    }
  }

  Future<T?> run<T>(
    Future<T> Function() operation, {
    String? successKey,
  }) async {
    if (busy) return null;
    busy = true;
    errorMessage = null;
    noticeMessage = null;
    notifyListeners();
    try {
      final value = await operation();
      await _refreshSnapshot();
      if (successKey != null) noticeMessage = t(successKey);
      return value;
    } on LocalizationCatalogException catch (error) {
      localizationFailure = error;
      return null;
    } on ControllerUserException catch (error) {
      errorMessage = t(error.localizationKey);
      return null;
    } on PurchaseOutcomeException catch (error) {
      errorMessage = _purchaseOutcomeMessage(error.outcome);
      return null;
    } on WalletConflictException {
      errorMessage = t('walletChanged');
      return null;
    } on FormatException {
      errorMessage = t('invalidBackup');
      return null;
    } on ArgumentError {
      errorMessage = t('invalidValue');
      return null;
    } on StateError {
      errorMessage = t('somethingWentWrong');
      return null;
    } on Object {
      errorMessage = t('somethingWentWrong');
      return null;
    } finally {
      busy = false;
      notifyListeners();
      unawaited(_drainStoreReconciliation());
    }
  }

  Future<void> _refreshSnapshot() async {
    data = await engine.snapshot();
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String currencyCode,
    required String massUnit,
    required String volumeUnit,
  }) async {
    await run<void>(() => engine.updateSettings(
          currencyCode: currencyCode,
          defaultMassUnit: massUnit,
          defaultVolumeUnit: volumeUnit,
          onboardingComplete: true,
          expectedRevision: data!.revision,
        ));
  }

  Future<void> setLocale(String locale) async {
    await run<void>(() async {
      // Validate the exact requested catalog before persisting the preference.
      final validated = await AppStrings.load(locale);
      await engine.updateSettings(
        locale: locale,
        expectedRevision: data!.revision,
      );
      strings = validated;
      if (reminderPermission case ReminderPresentationGateway presentation) {
        presentation.configureLocalizedPresentation(
          channelName: t('reminders'),
          channelDescription: t('remindersBody'),
        );
      }
    });
  }

  Future<void> updateSettings({
    String? currencyCode,
    String? massUnit,
    String? volumeUnit,
  }) async {
    await run<void>(() => engine.updateSettings(
          currencyCode: currencyCode,
          defaultMassUnit: massUnit,
          defaultVolumeUnit: volumeUnit,
          expectedRevision: data!.revision,
        ));
  }

  Future<AddResult?> addCylinder(AddCylinderDraft draft) async {
    final result = await run<AddResult>(
      () => engine.addOrGate(draft, expectedRevision: data!.revision),
    );
    if (result is CylinderAdded) {
      noticeMessage = t('cylinderSaved');
      notifyListeners();
    }
    return result;
  }

  Future<void> updateCylinder({
    required String cylinderId,
    required String nickname,
    required String gasType,
    required double? capacityValue,
    required String? capacityUnit,
    required String? serialNumber,
    required Money? acquisitionAmount,
    required DateTime? acquiredAt,
    required RelationshipType relationship,
    required String? supplierId,
  }) async {
    await run<void>(
      () => engine.updateCylinderDetails(
          cylinderId: cylinderId,
          nickname: nickname,
          gasType: gasType,
          capacityValue: capacityValue == null
              ? const Clear<double>()
              : SetValue(capacityValue),
          capacityUnit: capacityUnit == null
              ? const Clear<String>()
              : SetValue(capacityUnit),
          serialNumber: serialNumber == null
              ? const Clear<String>()
              : SetValue(serialNumber),
          acquisitionAmount: acquisitionAmount == null
              ? const Clear<Money>()
              : SetValue(acquisitionAmount),
          acquiredAt:
              acquiredAt == null ? const Clear<DateTime>() : SetValue(acquiredAt),
          relationship: relationship,
          supplierId:
              supplierId == null ? const Clear<String>() : SetValue(supplierId),
          expectedRevision: data!.revision,
        ),
      successKey: 'cylinderUpdated',
    );
  }

  Future<EditDecision?> editDecision(String cylinderId) =>
      run<EditDecision>(() => engine.canEditCylinder(cylinderId));

  Future<void> recordRefill({
    required String cylinderId,
    required DateTime occurredAt,
    Money? amount,
    String? note,
  }) async {
    await run<void>(() => engine.recordRefill(
          cylinderId: cylinderId,
          occurredAt: occurredAt,
          amount: amount,
          note: note,
          expectedRevision: data!.revision,
        ));
  }

  Future<void> recordExchange({
    required String cylinderId,
    required DateTime occurredAt,
    Money? amount,
    String? newSerialNumber,
    String? note,
  }) async {
    await run<void>(() => engine.recordExchange(
          cylinderId: cylinderId,
          occurredAt: occurredAt,
          amount: amount,
          newSerialNumber: newSerialNumber == null
              ? const Keep<String>()
              : SetValue(newSerialNumber),
          note: note,
          expectedRevision: data!.revision,
        ));
  }

  Future<void> recordCost({
    required String cylinderId,
    required DateTime occurredAt,
    required Money amount,
    String? note,
  }) async {
    await run<void>(() => engine.recordCost(
          cylinderId: cylinderId,
          occurredAt: occurredAt,
          amount: amount,
          note: note,
          expectedRevision: data!.revision,
        ));
  }

  Future<void> markReturned(String cylinderId) async {
    await run<void>(() => engine.markReturned(
          cylinderId,
          expectedRevision: data!.revision,
        ));
  }

  Future<void> archive(String cylinderId) async {
    await run<void>(() => engine.archiveCylinder(
          cylinderId,
          expectedRevision: data!.revision,
        ));
  }

  Future<void> deleteCylinder(String cylinderId) async {
    await run<void>(() => engine.deleteCylinder(
          cylinderId,
          confirmed: true,
          expectedRevision: data!.revision,
        ));
  }

  Future<void> createReminder({
    required String cylinderId,
    required ReminderKind kind,
    required String title,
    required DateTime dueAt,
  }) async {
    await run<ReminderResult>(() => engine.createReminder(
          cylinderId: cylinderId,
          kind: kind,
          title: title,
          dueAt: dueAt,
          expectedRevision: data!.revision,
        ));
  }

  Future<void> completeReminder(String reminderId) async {
    await run<void>(() => engine.completeReminder(
          reminderId,
          expectedRevision: data!.revision,
        ));
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    await run<void>(() async {
      if (enabled && !await reminderPermission.requestPermission()) {
        throw const ControllerUserException('notificationPermissionDenied');
      }
      await engine.setRemindersEnabled(enabled);
    });
  }

  Future<void> createSupplier(String name, {String? notes}) async {
    await run<Supplier>(() => engine.createSupplier(
          name,
          notes: notes,
          expectedRevision: data!.revision,
        ));
  }

  Future<Cylinder?> purchase(String productId) async {
    final result = await run<Cylinder?>(
      () => engine.purchaseAndResume(productId),
    );
    if (errorMessage == null && isPro) {
      noticeMessage = t('purchaseActivated');
      notifyListeners();
    }
    await _refreshProducts();
    return result;
  }

  String _purchaseOutcomeMessage(PurchaseOutcome outcome) => switch (outcome) {
        PurchaseOutcome.pending => t('purchasePending'),
        PurchaseOutcome.cancelled => t('purchaseCancelled'),
        PurchaseOutcome.notFound => t('purchaseNotFound'),
        PurchaseOutcome.failed || PurchaseOutcome.unverified =>
          t('purchaseFailed'),
      };

  @override
  void dispose() {
    final subscription = _storeUpdateSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }

  Future<void> restore() => refreshStoreAccess();

  Future<void> manageSubscription() async {
    await run<void>(billing.openSubscriptionManagement);
  }

  Future<void> exportBackup({Rect? sharePositionOrigin}) async {
    await run<void>(() async {
      final encoded = await engine.exportBackup();
      await _backupFiles.shareBackup(
        encoded,
        localizedTitle: t('exportBackup'),
        localizedPrivacyNote: t('backupExportPrivacy'),
        sharePositionOrigin: sharePositionOrigin,
      );
    }, successKey: 'backupExported');
  }

  Future<bool> importBackup() async {
    final result = await run<bool>(() async {
      final encoded = await _backupFiles.pickBackup();
      if (encoded == null) return false;
      await engine.importBackup(encoded, expectedRevision: data!.revision);
      final next = await engine.snapshot();
      final nextStrings = await AppStrings.load(next.settings.locale);
      data = next;
      strings = nextStrings;
      return true;
    });
    if (result != true) return false;
    noticeMessage = t('backupImported');
    notifyListeners();
    return true;
  }

  Future<void> deleteAll() async {
    await run<void>(
      () => engine.deleteAllWalletData(confirmed: true),
    );
  }

  Future<void> recoverCorruptStoreFromBackup() async {
    final recovery = engine.repo;
    if (recovery is! CorruptionRecoveryRepository || busy) return;
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final encoded = await _backupFiles.pickBackup();
      if (encoded == null) return;
      final validated = BackupCodec.decode(encoded);
      await recovery.replaceCorruptStore(validated);
      startupError = null;
      data = null;
      await bootstrap();
      noticeMessage = t('backupImported');
    } on FormatException {
      errorMessage = t('invalidBackup');
    } on Object {
      errorMessage = t('somethingWentWrong');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> clearCorruptStore() async {
    final recovery = engine.repo;
    if (recovery is! CorruptionRecoveryRepository || busy) return;
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await engine.scheduler.cancelAll();
      await recovery.clearCorruptStore(confirmed: true);
      startupError = null;
      data = null;
      await bootstrap();
    } on Object {
      errorMessage = t('somethingWentWrong');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> openLegal(Uri uri) async {
    await run<void>(() => _links.open(uri));
  }

  Future<void> selectFreeEditable(Set<String> cylinderIds) async {
    await run<void>(() => engine.selectFreeEditable(
          cylinderIds,
          expectedRevision: data!.revision,
        ));
  }
}
