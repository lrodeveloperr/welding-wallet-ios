// Welding Gas Wallet — deterministic mobile domain core v1.1
//
// Local-first, UI-independent and intentionally free of Flutter imports.
// A production database adapter must implement AtomicWalletRepository by using
// one durable database transaction for every `transact` call.

import 'dart:async';
import 'dart:convert';

const int walletSchemaVersion = 2;
const int freeEditableCylinderLimit = 3;
const int maximumBackupBytes = 5 * 1024 * 1024;

const supportedLocales = <String>[
  'en', 'es', 'pt', 'fr', 'de', 'it', 'nl', 'pl', 'cs', 'ro',
  'hu', 'sv', 'nb', 'da', 'fi', 'tr', 'ar', 'hi', 'bn', 'id',
  'vi', 'th', 'ja', 'ko', 'zh-Hans', 'zh-Hant', 'uk', 'el', 'ms', 'fil',
];

// Active ISO 4217 alphabetic codes. Historic codes are deliberately rejected
// on new writes; an explicit migration is required if one is ever supported.
const iso4217Codes = <String>{
  'AED', 'AFN', 'ALL', 'AMD', 'ANG', 'AOA', 'ARS', 'AUD', 'AWG', 'AZN',
  'BAM', 'BBD', 'BDT', 'BGN', 'BHD', 'BIF', 'BMD', 'BND', 'BOB', 'BOV',
  'BRL', 'BSD', 'BTN', 'BWP', 'BYN', 'BZD', 'CAD', 'CDF', 'CHE', 'CHF',
  'CHW', 'CLF', 'CLP', 'CNY', 'COP', 'COU', 'CRC', 'CUP', 'CVE', 'CZK',
  'DJF', 'DKK', 'DOP', 'DZD', 'EGP', 'ERN', 'ETB', 'EUR', 'FJD', 'FKP',
  'GBP', 'GEL', 'GHS', 'GIP', 'GMD', 'GNF', 'GTQ', 'GYD', 'HKD', 'HNL',
  'HTG', 'HUF', 'IDR', 'ILS', 'INR', 'IQD', 'IRR', 'ISK', 'JMD', 'JOD',
  'JPY', 'KES', 'KGS', 'KHR', 'KMF', 'KPW', 'KRW', 'KWD', 'KYD', 'KZT',
  'LAK', 'LBP', 'LKR', 'LRD', 'LSL', 'LYD', 'MAD', 'MDL', 'MGA', 'MKD',
  'MMK', 'MNT', 'MOP', 'MRU', 'MUR', 'MVR', 'MWK', 'MXN', 'MXV', 'MYR',
  'MZN', 'NAD', 'NGN', 'NIO', 'NOK', 'NPR', 'NZD', 'OMR', 'PAB', 'PEN',
  'PGK', 'PHP', 'PKR', 'PLN', 'PYG', 'QAR', 'RON', 'RSD', 'RUB', 'RWF',
  'SAR', 'SBD', 'SCR', 'SDG', 'SEK', 'SGD', 'SHP', 'SLE', 'SOS', 'SRD',
  'SSP', 'STN', 'SVC', 'SYP', 'SZL', 'THB', 'TJS', 'TMT', 'TND', 'TOP',
  'TRY', 'TTD', 'TWD', 'TZS', 'UAH', 'UGX', 'USD', 'USN', 'UYI', 'UYU',
  'UYW', 'UZS', 'VED', 'VES', 'VND', 'VUV', 'WST', 'XAF', 'XAG', 'XAU',
  'XBA', 'XBB', 'XBC', 'XBD', 'XCD', 'XDR', 'XOF', 'XPD', 'XPF', 'XPT',
  'XSU', 'XTS', 'XUA', 'XXX', 'YER', 'ZAR', 'ZMW', 'ZWG',
};

enum StorePlatform { android, ios }
enum AccessTier { free, pro }
enum EntitlementSource { none, googlePlaySubscription, appStoreLifetime }
enum RelationshipType { owned, rented, leased, deposit, notSure }
enum CylinderLifecycle { active, returned, exchanged, archived }
enum CylinderEventType {
  created,
  refill,
  exchange,
  purchase,
  rentalPayment,
  leasePayment,
  depositPaid,
  depositReturned,
  cost,
  supplierChanged,
  relationshipChanged,
  note,
  photoAdded,
  reminderCreated,
  reminderCompleted,
  returned,
  archived,
}
enum ReminderKind { refill, rental, lease, deposit, check, custom }
enum ReminderDelivery { idle, needsScheduling, scheduled, needsCancellation }
enum PaywallReason { addFourthCylinder, editLockedCylinderAfterDowngrade }

String canonicalLocale(String? candidate) {
  if (candidate == null || candidate.trim().isEmpty) return 'en';
  final normalized = candidate.trim().replaceAll('_', '-');
  final lower = normalized.toLowerCase();
  for (final supported in supportedLocales) {
    if (supported.toLowerCase() == lower) return supported;
  }
  final parts = lower.split('-');
  if (parts.first == 'zh') {
    final tags = parts.skip(1).toSet();
    if (tags.intersection({'hant', 'tw', 'hk', 'mo'}).isNotEmpty) {
      return 'zh-Hant';
    }
    return 'zh-Hans';
  }
  final language = parts.first;
  return supportedLocales.contains(language) ? language : 'en';
}

bool isSupportedLocaleCandidate(String candidate) {
  final normalized = candidate.trim().replaceAll('_', '-').toLowerCase();
  if (normalized.isEmpty) return false;
  if (supportedLocales.any((v) => v.toLowerCase() == normalized)) return true;
  final language = normalized.split('-').first;
  return language == 'zh' || supportedLocales.contains(language);
}

bool isRtlLocale(String locale) => canonicalLocale(locale) == 'ar';

String normalizedCurrency(String? candidate, {String fallback = 'USD'}) {
  final value = (candidate ?? '').trim().toUpperCase();
  if (iso4217Codes.contains(value)) return value;
  final safeFallback = fallback.trim().toUpperCase();
  return iso4217Codes.contains(safeFallback) ? safeFallback : 'USD';
}

String defaultCurrencyForLocale(String locale) => switch (canonicalLocale(locale)) {
      'en' => 'USD', 'es' => 'EUR', 'pt' => 'BRL', 'fr' => 'EUR',
      'de' => 'EUR', 'it' => 'EUR', 'nl' => 'EUR', 'pl' => 'PLN',
      'cs' => 'CZK', 'ro' => 'RON', 'hu' => 'HUF', 'sv' => 'SEK',
      'nb' => 'NOK', 'da' => 'DKK', 'fi' => 'EUR', 'tr' => 'TRY',
      'ar' => 'AED', 'hi' => 'INR', 'bn' => 'BDT', 'id' => 'IDR',
      'vi' => 'VND', 'th' => 'THB', 'ja' => 'JPY', 'ko' => 'KRW',
      'zh-Hans' => 'CNY', 'zh-Hant' => 'TWD', 'uk' => 'UAH',
      'el' => 'EUR', 'ms' => 'MYR', 'fil' => 'PHP', _ => 'USD',
    };

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  if (name == null || name.isEmpty) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown enum value: $name');
}

DateTime _date(Object? raw, String field) {
  final parsed = DateTime.tryParse(raw?.toString() ?? '');
  if (parsed == null) throw FormatException('Invalid $field date.');
  return parsed.toUtc();
}

String? _textOrNull(Object? raw) {
  final value = raw?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

sealed class FieldPatch<T> {
  const FieldPatch();
  T? apply(T? current);
}

class Keep<T> extends FieldPatch<T> {
  const Keep();
  @override
  T? apply(T? current) => current;
}

class SetValue<T> extends FieldPatch<T> {
  final T value;
  const SetValue(this.value);
  @override
  T apply(T? current) => value;
}

class Clear<T> extends FieldPatch<T> {
  const Clear();
  @override
  T? apply(T? current) => null;
}

class Money {
  final int minorUnits;
  final String currencyCode;

  Money({required this.minorUnits, required String currencyCode})
      : currencyCode = _requireCurrency(currencyCode);

  static String _requireCurrency(String value) {
    final normalized = value.trim().toUpperCase();
    if (!iso4217Codes.contains(normalized)) {
      throw ArgumentError('Unsupported ISO 4217 currency: $value');
    }
    return normalized;
  }

  Map<String, Object?> toJson() => {
        'minorUnits': minorUnits,
        'currencyCode': currencyCode,
      };

  factory Money.fromJson(Map<String, Object?> json) => Money(
        minorUnits: (json['minorUnits'] as num?)?.toInt() ??
            (throw const FormatException('Money minorUnits is required.')),
        currencyCode: json['currencyCode']?.toString() ?? '',
      );
}

class Supplier {
  final String id;
  final String name;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  Supplier copyWith({
    String? name,
    FieldPatch<String> notes = const Keep(),
    DateTime? updatedAt,
  }) =>
      Supplier(
        id: id,
        name: name ?? this.name,
        notes: notes.apply(this.notes),
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'notes': notes,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Supplier.fromJson(Map<String, Object?> json) => Supplier(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        notes: _textOrNull(json['notes']),
        createdAt: _date(json['createdAt'], 'createdAt'),
        updatedAt: _date(json['updatedAt'], 'updatedAt'),
      );
}

class AppSettings {
  final String locale;
  final String currencyCode;
  final String defaultMassUnit;
  final String defaultVolumeUnit;
  final bool remindersEnabled;
  final bool onboardingComplete;

  AppSettings({
    required String locale,
    required String currencyCode,
    required String defaultMassUnit,
    required String defaultVolumeUnit,
    required this.remindersEnabled,
    required this.onboardingComplete,
  })  : locale = canonicalLocale(locale),
        currencyCode = normalizedCurrency(
          currencyCode,
          fallback: defaultCurrencyForLocale(locale),
        ),
        defaultMassUnit = const {'kg', 'lb'}.contains(defaultMassUnit)
            ? defaultMassUnit
            : 'kg',
        defaultVolumeUnit = const {'L', 'm3', 'ft3'}.contains(defaultVolumeUnit)
            ? defaultVolumeUnit
            : 'L';

  AppSettings copyWith({
    String? locale,
    String? currencyCode,
    String? defaultMassUnit,
    String? defaultVolumeUnit,
    bool? remindersEnabled,
    bool? onboardingComplete,
  }) =>
      AppSettings(
        locale: locale ?? this.locale,
        currencyCode: currencyCode ?? this.currencyCode,
        defaultMassUnit: defaultMassUnit ?? this.defaultMassUnit,
        defaultVolumeUnit: defaultVolumeUnit ?? this.defaultVolumeUnit,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      );

  Map<String, Object?> toJson() => {
        'locale': locale,
        'currencyCode': currencyCode,
        'defaultMassUnit': defaultMassUnit,
        'defaultVolumeUnit': defaultVolumeUnit,
        'remindersEnabled': remindersEnabled,
        'onboardingComplete': onboardingComplete,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        locale: json['locale']?.toString() ?? 'en',
        currencyCode: json['currencyCode']?.toString() ?? 'USD',
        defaultMassUnit: json['defaultMassUnit']?.toString() ?? 'kg',
        defaultVolumeUnit: json['defaultVolumeUnit']?.toString() ?? 'L',
        remindersEnabled: json['remindersEnabled'] == true,
        onboardingComplete: json['onboardingComplete'] == true,
      );
}

class Cylinder {
  final String id;
  final String nickname;
  final String gasType;
  final double? capacityValue;
  final String? capacityUnit;
  final String? serialNumber;
  final String? localPhotoUri;
  final RelationshipType relationship;
  final CylinderLifecycle lifecycle;
  final String? supplierId;
  final Money? acquisitionAmount;
  final DateTime? acquiredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFreeEditableSelection;

  const Cylinder({
    required this.id,
    required this.nickname,
    required this.gasType,
    required this.relationship,
    required this.lifecycle,
    required this.createdAt,
    required this.updatedAt,
    this.capacityValue,
    this.capacityUnit,
    this.serialNumber,
    this.localPhotoUri,
    this.supplierId,
    this.acquisitionAmount,
    this.acquiredAt,
    this.isFreeEditableSelection = false,
  });

  bool get consumesCurrentSlot =>
      lifecycle == CylinderLifecycle.active ||
      lifecycle == CylinderLifecycle.exchanged;

  Cylinder copyWith({
    String? nickname,
    String? gasType,
    FieldPatch<double> capacityValue = const Keep(),
    FieldPatch<String> capacityUnit = const Keep(),
    FieldPatch<String> serialNumber = const Keep(),
    FieldPatch<String> localPhotoUri = const Keep(),
    RelationshipType? relationship,
    CylinderLifecycle? lifecycle,
    FieldPatch<String> supplierId = const Keep(),
    FieldPatch<Money> acquisitionAmount = const Keep(),
    FieldPatch<DateTime> acquiredAt = const Keep(),
    DateTime? updatedAt,
    bool? isFreeEditableSelection,
  }) =>
      Cylinder(
        id: id,
        nickname: nickname ?? this.nickname,
        gasType: gasType ?? this.gasType,
        capacityValue: capacityValue.apply(this.capacityValue),
        capacityUnit: capacityUnit.apply(this.capacityUnit),
        serialNumber: serialNumber.apply(this.serialNumber),
        localPhotoUri: localPhotoUri.apply(this.localPhotoUri),
        relationship: relationship ?? this.relationship,
        lifecycle: lifecycle ?? this.lifecycle,
        supplierId: supplierId.apply(this.supplierId),
        acquisitionAmount: acquisitionAmount.apply(this.acquisitionAmount),
        acquiredAt: acquiredAt.apply(this.acquiredAt),
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isFreeEditableSelection:
            isFreeEditableSelection ?? this.isFreeEditableSelection,
      );

  Map<String, Object?> toJson() => {
        'id': id, 'nickname': nickname, 'gasType': gasType,
        'capacityValue': capacityValue, 'capacityUnit': capacityUnit,
        'serialNumber': serialNumber, 'localPhotoUri': localPhotoUri,
        'relationship': relationship.name, 'lifecycle': lifecycle.name,
        'supplierId': supplierId, 'acquisitionAmount': acquisitionAmount?.toJson(),
        'acquiredAt': acquiredAt?.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'isFreeEditableSelection': isFreeEditableSelection,
      };

  factory Cylinder.fromJson(Map<String, Object?> json) => Cylinder(
        id: json['id']?.toString() ?? '',
        nickname: json['nickname']?.toString() ?? '',
        gasType: json['gasType']?.toString() ?? '',
        capacityValue: (json['capacityValue'] as num?)?.toDouble(),
        capacityUnit: _textOrNull(json['capacityUnit']),
        serialNumber: _textOrNull(json['serialNumber']),
        localPhotoUri: _textOrNull(json['localPhotoUri']),
        relationship: _enumValue(
          RelationshipType.values, json['relationship'], RelationshipType.notSure),
        lifecycle: _enumValue(
          CylinderLifecycle.values, json['lifecycle'], CylinderLifecycle.active),
        supplierId: _textOrNull(json['supplierId']),
        acquisitionAmount: json['acquisitionAmount'] is Map<Object?, Object?>
            ? Money.fromJson(Map<String, Object?>.from(
                json['acquisitionAmount']! as Map<Object?, Object?>))
            : null,
        acquiredAt: json['acquiredAt'] == null
            ? null : _date(json['acquiredAt'], 'acquiredAt'),
        createdAt: _date(json['createdAt'], 'createdAt'),
        updatedAt: _date(json['updatedAt'], 'updatedAt'),
        isFreeEditableSelection: json['isFreeEditableSelection'] == true,
      );
}

class CylinderEvent {
  final String id;
  final String cylinderId;
  final CylinderEventType type;
  final DateTime occurredAt;
  final String? supplierId;
  final Money? amount;
  final String? note;
  final Map<String, Object?> metadata;

  const CylinderEvent({
    required this.id,
    required this.cylinderId,
    required this.type,
    required this.occurredAt,
    this.supplierId,
    this.amount,
    this.note,
    this.metadata = const {},
  });

  Map<String, Object?> toJson() => {
        'id': id, 'cylinderId': cylinderId, 'type': type.name,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'supplierId': supplierId, 'amount': amount?.toJson(), 'note': note,
        'metadata': metadata,
      };

  factory CylinderEvent.fromJson(Map<String, Object?> json) => CylinderEvent(
        id: json['id']?.toString() ?? '',
        cylinderId: json['cylinderId']?.toString() ?? '',
        type: _enumValue(CylinderEventType.values, json['type'], CylinderEventType.cost),
        occurredAt: _date(json['occurredAt'], 'occurredAt'),
        supplierId: _textOrNull(json['supplierId']),
        amount: json['amount'] is Map<Object?, Object?>
            ? Money.fromJson(Map<String, Object?>.from(
                json['amount']! as Map<Object?, Object?>))
            : null,
        note: _textOrNull(json['note']),
        metadata: json['metadata'] is Map<Object?, Object?>
            ? Map<String, Object?>.from(
                json['metadata']! as Map<Object?, Object?>) : const {},
      );
}

class Reminder {
  final String id;
  final String cylinderId;
  final ReminderKind kind;
  final String title;
  final DateTime dueAt;
  final bool completed;
  final DateTime createdAt;
  final ReminderDelivery delivery;

  const Reminder({
    required this.id,
    required this.cylinderId,
    required this.kind,
    required this.title,
    required this.dueAt,
    required this.createdAt,
    required this.delivery,
    this.completed = false,
  });

  Reminder copyWith({bool? completed, ReminderDelivery? delivery}) => Reminder(
        id: id, cylinderId: cylinderId, kind: kind, title: title, dueAt: dueAt,
        createdAt: createdAt, completed: completed ?? this.completed,
        delivery: delivery ?? this.delivery,
      );

  Map<String, Object?> toJson() => {
        'id': id, 'cylinderId': cylinderId, 'kind': kind.name, 'title': title,
        'dueAt': dueAt.toUtc().toIso8601String(), 'completed': completed,
        'createdAt': createdAt.toUtc().toIso8601String(), 'delivery': delivery.name,
      };

  factory Reminder.fromJson(Map<String, Object?> json) => Reminder(
        id: json['id']?.toString() ?? '',
        cylinderId: json['cylinderId']?.toString() ?? '',
        kind: _enumValue(ReminderKind.values, json['kind'], ReminderKind.custom),
        title: json['title']?.toString() ?? '',
        dueAt: _date(json['dueAt'], 'dueAt'),
        completed: json['completed'] == true,
        createdAt: _date(json['createdAt'], 'createdAt'),
        delivery: _enumValue(ReminderDelivery.values, json['delivery'],
            json['completed'] == true
                ? ReminderDelivery.needsCancellation
                : ReminderDelivery.needsScheduling),
      );
}

class AddCylinderDraft {
  final String nickname;
  final String gasType;
  final double? capacityValue;
  final String? capacityUnit;
  final String? serialNumber;
  final String? localPhotoUri;
  final RelationshipType relationship;
  final String? supplierId;
  final Money? acquisitionAmount;
  final DateTime? acquiredAt;

  const AddCylinderDraft({
    required this.nickname,
    required this.gasType,
    required this.relationship,
    this.capacityValue,
    this.capacityUnit,
    this.serialNumber,
    this.localPhotoUri,
    this.supplierId,
    this.acquisitionAmount,
    this.acquiredAt,
  });

  Map<String, Object?> toJson() => {
        'nickname': nickname, 'gasType': gasType, 'capacityValue': capacityValue,
        'capacityUnit': capacityUnit, 'serialNumber': serialNumber,
        'localPhotoUri': localPhotoUri, 'relationship': relationship.name,
        'supplierId': supplierId, 'acquisitionAmount': acquisitionAmount?.toJson(),
        'acquiredAt': acquiredAt?.toUtc().toIso8601String(),
      };

  factory AddCylinderDraft.fromJson(Map<String, Object?> json) => AddCylinderDraft(
        nickname: json['nickname']?.toString() ?? '',
        gasType: json['gasType']?.toString() ?? '',
        capacityValue: (json['capacityValue'] as num?)?.toDouble(),
        capacityUnit: _textOrNull(json['capacityUnit']),
        serialNumber: _textOrNull(json['serialNumber']),
        localPhotoUri: _textOrNull(json['localPhotoUri']),
        relationship: _enumValue(
          RelationshipType.values, json['relationship'], RelationshipType.notSure),
        supplierId: _textOrNull(json['supplierId']),
        acquisitionAmount: json['acquisitionAmount'] is Map<Object?, Object?>
            ? Money.fromJson(Map<String, Object?>.from(
                json['acquisitionAmount']! as Map<Object?, Object?>))
            : null,
        acquiredAt: json['acquiredAt'] == null
            ? null : _date(json['acquiredAt'], 'acquiredAt'),
      );
}

class Entitlement {
  final AccessTier tier;
  final EntitlementSource source;
  final DateTime? validUntil;
  final bool willRenew;

  const Entitlement({
    required this.tier,
    required this.source,
    this.validUntil,
    this.willRenew = false,
  });

  const Entitlement.free()
      : tier = AccessTier.free,
        source = EntitlementSource.none,
        validUntil = null,
        willRenew = false;

  bool isProAt(DateTime now) {
    if (tier != AccessTier.pro) return false;
    if (source == EntitlementSource.appStoreLifetime) return true;
    return validUntil != null && !now.toUtc().isAfter(validUntil!.toUtc());
  }
}

class WalletData {
  final int schemaVersion;
  final int revision;
  final AppSettings settings;
  final List<Supplier> suppliers;
  final List<Cylinder> cylinders;
  final List<CylinderEvent> events;
  final List<Reminder> reminders;
  final AddCylinderDraft? pendingDraft;
  final Entitlement entitlementCache;

  const WalletData({
    required this.schemaVersion,
    required this.revision,
    required this.settings,
    required this.suppliers,
    required this.cylinders,
    required this.events,
    required this.reminders,
    required this.pendingDraft,
    required this.entitlementCache,
  });

  factory WalletData.empty({String locale = 'en', String? currencyCode}) {
    final safeLocale = canonicalLocale(locale);
    return WalletData(
      schemaVersion: walletSchemaVersion,
      revision: 0,
      settings: AppSettings(
        locale: safeLocale,
        currencyCode: normalizedCurrency(currencyCode,
            fallback: defaultCurrencyForLocale(safeLocale)),
        defaultMassUnit: 'kg',
        defaultVolumeUnit: 'L',
        remindersEnabled: false,
        onboardingComplete: false,
      ),
      suppliers: const [], cylinders: const [], events: const [], reminders: const [],
      pendingDraft: null, entitlementCache: const Entitlement.free(),
    );
  }

  WalletData next({
    AppSettings? settings,
    List<Supplier>? suppliers,
    List<Cylinder>? cylinders,
    List<CylinderEvent>? events,
    List<Reminder>? reminders,
    FieldPatch<AddCylinderDraft> pendingDraft = const Keep(),
    Entitlement? entitlementCache,
  }) =>
      WalletData(
        schemaVersion: walletSchemaVersion,
        revision: revision + 1,
        settings: settings ?? this.settings,
        suppliers: List<Supplier>.unmodifiable(suppliers ?? this.suppliers),
        cylinders: List<Cylinder>.unmodifiable(cylinders ?? this.cylinders),
        events: List<CylinderEvent>.unmodifiable(events ?? this.events),
        reminders: List<Reminder>.unmodifiable(reminders ?? this.reminders),
        pendingDraft: pendingDraft.apply(this.pendingDraft),
        entitlementCache: entitlementCache ?? this.entitlementCache,
      );

  Map<String, Object?> backupPayload() => {
        'settings': settings.toJson(),
        'suppliers': suppliers.map((v) => v.toJson()).toList(),
        'cylinders': cylinders.map((v) {
          final json = v.toJson();
          json['localPhotoUri'] = null;
          return json;
        }).toList(),
        'events': events.map((v) => v.toJson()).toList(),
        'reminders': reminders.map((v) => v.toJson()).toList(),
        'pendingDraft': pendingDraft == null
            ? null
            : (pendingDraft!.toJson()..['localPhotoUri'] = null),
        'photosExcluded': true,
      };
}

class TransactionOutcome<T> {
  final WalletData state;
  final T value;
  const TransactionOutcome(this.state, this.value);
}

class WalletConflictException implements Exception {
  final int expected;
  final int actual;
  const WalletConflictException(this.expected, this.actual);
  @override
  String toString() => 'Wallet changed (expected revision $expected, found $actual).';
}

abstract interface class AtomicWalletRepository {
  Future<WalletData> read();

  // The adapter MUST serialize calls, compare expectedRevision in the same
  // database transaction, durably persist outcome.state, then commit once.
  Future<T> transact<T>(
    TransactionOutcome<T> Function(WalletData current) mutation, {
    int? expectedRevision,
  });

  // Import is a single replace transaction; never clear then insert row-by-row.
  Future<WalletData> replaceFromBackup(
    WalletData imported, {
    required int expectedRevision,
  });
}

/// Optional production boundary for repositories that persist user-editable
/// files. A new process must ignore persisted entitlement fields until the
/// native store gateway has verified them for this session.
abstract interface class SessionEntitlementTrust {
  void acceptStoreVerifiedEntitlement(Entitlement entitlement);
}

abstract interface class ResidualWalletDataPurger {
  Future<void> purgeResidualWalletFiles();
}

abstract interface class CorruptionRecoveryRepository {
  Future<WalletData> replaceCorruptStore(WalletData validatedBackup);
  Future<WalletData> clearCorruptStore({required bool confirmed});
}

abstract interface class IdFactory { String newId(); }
abstract interface class Clock { DateTime now(); }
abstract interface class ReminderScheduler {
  Future<void> schedule(Reminder reminder);
  Future<void> cancel(String reminderId);
  Future<void> cancelAll();
}

class StoreProduct {
  final String id;
  final String localizedPrice;
  final String localizedPeriodLabel;
  final bool isDefault;
  const StoreProduct({
    required this.id,
    required this.localizedPrice,
    required this.localizedPeriodLabel,
    required this.isDefault,
  });
}

enum PurchaseOutcome { pending, cancelled, failed, unverified, notFound }

class PurchaseOutcomeException implements Exception {
  const PurchaseOutcomeException(this.outcome);

  final PurchaseOutcome outcome;

  @override
  String toString() => 'Purchase flow ended with ${outcome.name}.';
}

abstract interface class StoreBillingGateway {
  StorePlatform get platform;
  Future<List<StoreProduct>> loadProducts();
  Future<Entitlement> purchaseVerified(String productId);
  Future<Entitlement> restoreOrRefreshVerified();
  Future<void> openSubscriptionManagement();
}

/// Optional native-store signal for a transaction that changes while the app
/// remains foregrounded (for example pending payment becoming purchased).
abstract interface class StoreEntitlementUpdateGateway {
  Stream<void> get entitlementRefreshRequests;
}

class ProductIds {
  static const androidMonthly = 'com.gooduse.weldinggaswallet.pro.monthly';
  static const androidAnnual = 'com.gooduse.weldinggaswallet.pro.annual';
  static const iosLifetime = 'com.gooduse.weldinggaswallet.pro.lifetime';
  static List<String> forPlatform(StorePlatform platform) =>
      platform == StorePlatform.android
          ? const [androidAnnual, androidMonthly]
          : const [iosLifetime];
}

sealed class AddResult { const AddResult(); }
class CylinderAdded extends AddResult {
  final Cylinder cylinder;
  const CylinderAdded(this.cylinder);
}
class AddRequiresPaywall extends AddResult {
  final PaywallReason reason;
  const AddRequiresPaywall(this.reason);
}

sealed class EditDecision { const EditDecision(); }
class Editable extends EditDecision { const Editable(); }
class Locked extends EditDecision {
  final PaywallReason reason;
  const Locked(this.reason);
}
class MissingCylinder extends EditDecision { const MissingCylinder(); }

sealed class DowngradeDecision { const DowngradeDecision(); }
class DowngradeReady extends DowngradeDecision { const DowngradeReady(); }
class RequiresFreeSelection extends DowngradeDecision {
  final int maximumEditable;
  const RequiresFreeSelection(this.maximumEditable);
}

class ReminderResult {
  final Reminder reminder;
  final bool systemScheduleConfirmed;
  const ReminderResult(this.reminder, this.systemScheduleConfirmed);
}

class WeldingGasWalletEngine {
  final AtomicWalletRepository repo;
  final StoreBillingGateway billing;
  final ReminderScheduler scheduler;
  final IdFactory ids;
  final Clock clock;

  const WeldingGasWalletEngine({
    required this.repo,
    required this.billing,
    required this.scheduler,
    required this.ids,
    required this.clock,
  });

  Future<WalletData> snapshot() => repo.read();

  Future<Supplier> createSupplier(
    String name, {
    String? notes,
    int? expectedRevision,
  }) =>
      repo.transact((current) {
        final now = clock.now().toUtc();
        final supplier = Supplier(
          id: ids.newId(),
          name: _requiredText(name, 'supplier name'),
          notes: _textOrNull(notes),
          createdAt: now,
          updatedAt: now,
        );
        return TransactionOutcome(
          current.next(suppliers: [...current.suppliers, supplier]), supplier);
      }, expectedRevision: expectedRevision);

  Future<Supplier> updateSupplier({
    required String supplierId,
    String? name,
    FieldPatch<String> notes = const Keep(),
    int? expectedRevision,
  }) =>
      repo.transact((current) {
        final index = current.suppliers.indexWhere((s) => s.id == supplierId);
        if (index < 0) throw StateError('Supplier not found.');
        final updated = current.suppliers[index].copyWith(
          name: name == null ? null : _requiredText(name, 'supplier name'),
          notes: notes,
          updatedAt: clock.now().toUtc(),
        );
        final suppliers = [...current.suppliers]..[index] = updated;
        return TransactionOutcome(current.next(suppliers: suppliers), updated);
      }, expectedRevision: expectedRevision);

  Future<void> updateSettings({
    String? locale,
    String? currencyCode,
    String? defaultMassUnit,
    String? defaultVolumeUnit,
    bool? onboardingComplete,
    int? expectedRevision,
  }) =>
      repo.transact((current) {
        if (locale != null && !isSupportedLocaleCandidate(locale)) {
          throw ArgumentError('Unsupported locale.');
        }
        if (defaultMassUnit != null && !const {'kg', 'lb'}.contains(defaultMassUnit)) {
          throw ArgumentError('Unsupported mass unit.');
        }
        if (defaultVolumeUnit != null &&
            !const {'L', 'm3', 'ft3'}.contains(defaultVolumeUnit)) {
          throw ArgumentError('Unsupported volume unit.');
        }
        final nextLocale = locale == null ? current.settings.locale : canonicalLocale(locale);
        final nextCurrency = currencyCode == null
            ? current.settings.currencyCode
            : Money._requireCurrency(currencyCode);
        final settings = current.settings.copyWith(
          locale: nextLocale,
          currencyCode: nextCurrency,
          defaultMassUnit: defaultMassUnit,
          defaultVolumeUnit: defaultVolumeUnit,
          onboardingComplete: onboardingComplete,
        );
        return TransactionOutcome(current.next(settings: settings), null);
      }, expectedRevision: expectedRevision);

  Future<AddResult> addOrGate(
    AddCylinderDraft draft, {
    int? expectedRevision,
  }) async {
    _validateDraft(draft);
    return repo.transact((current) {
      _assertSupplierExists(current, draft.supplierId);
      final isPro = current.entitlementCache.isProAt(clock.now());
      final slots = current.cylinders.where((c) => c.consumesCurrentSlot).length;
      if (!isPro && slots >= freeEditableCylinderLimit) {
        return TransactionOutcome(
          current.next(pendingDraft: SetValue(draft)),
          const AddRequiresPaywall(PaywallReason.addFourthCylinder),
        );
      }
      final result = _insertDraft(current, draft, freeSelection: !isPro);
      return TransactionOutcome(result.$1, CylinderAdded(result.$2));
    }, expectedRevision: expectedRevision);
  }

  (WalletData, Cylinder) _insertDraft(
    WalletData current,
    AddCylinderDraft draft, {
    required bool freeSelection,
  }) {
    final now = clock.now().toUtc();
    final cylinder = Cylinder(
      id: ids.newId(), nickname: draft.nickname.trim(), gasType: draft.gasType.trim(),
      capacityValue: draft.capacityValue, capacityUnit: _textOrNull(draft.capacityUnit),
      serialNumber: _textOrNull(draft.serialNumber),
      localPhotoUri: _textOrNull(draft.localPhotoUri),
      relationship: draft.relationship, lifecycle: CylinderLifecycle.active,
      supplierId: _textOrNull(draft.supplierId),
      acquisitionAmount: draft.acquisitionAmount, acquiredAt: draft.acquiredAt,
      createdAt: now, updatedAt: now,
      isFreeEditableSelection: freeSelection,
    );
    final event = CylinderEvent(
      id: ids.newId(), cylinderId: cylinder.id, type: CylinderEventType.created,
      occurredAt: draft.acquiredAt?.toUtc() ?? now,
      supplierId: cylinder.supplierId,
      amount: cylinder.acquisitionAmount,
      metadata: {'relationship': cylinder.relationship.name},
    );
    return (
      current.next(
        cylinders: [...current.cylinders, cylinder],
        events: [...current.events, event],
        pendingDraft: const Clear(),
      ),
      cylinder,
    );
  }

  Future<List<StoreProduct>> getPaywallProducts() async {
    final expected = ProductIds.forPlatform(billing.platform);
    final products = (await billing.loadProducts())
        .where((p) => expected.contains(p.id) && p.localizedPrice.trim().isNotEmpty)
        .map((p) => StoreProduct(
              id: p.id,
              localizedPrice: p.localizedPrice,
              localizedPeriodLabel: p.localizedPeriodLabel,
              isDefault: billing.platform == StorePlatform.android
                  ? p.id == ProductIds.androidAnnual
                  : p.id == ProductIds.iosLifetime,
            ))
        .toList();
    products.sort((a, b) => expected.indexOf(a.id).compareTo(expected.indexOf(b.id)));
    return products;
  }

  Future<Cylinder?> purchaseAndResume(String productId) async {
    if (!ProductIds.forPlatform(billing.platform).contains(productId)) {
      throw ArgumentError('Product does not belong to this platform.');
    }
    final verified = await billing.purchaseVerified(productId);
    _validateVerifiedEntitlement(verified);
    final resumed = await _applyEntitlementAndResume(verified);
    await enforceDowngradeIfNeeded();
    return resumed;
  }

  Future<Cylinder?> restoreAndResume() async {
    final verified = await billing.restoreOrRefreshVerified();
    _validateVerifiedEntitlement(verified);
    final resumed = await _applyEntitlementAndResume(verified);
    await enforceDowngradeIfNeeded();
    return resumed;
  }

  Future<Cylinder?> _applyEntitlementAndResume(Entitlement verified) {
    if (repo case SessionEntitlementTrust trust) {
      trust.acceptStoreVerifiedEntitlement(verified);
    }
    return repo.transact((current) {
        final isPro = verified.isProAt(clock.now());
        final pending = current.pendingDraft;
        if (isPro && pending != null) {
          final inserted = _insertDraft(current, pending, freeSelection: false);
          final insertedState = inserted.$1;
          final clearedSelections = insertedState.cylinders
              .map((c) => c.isFreeEditableSelection
                  ? c.copyWith(isFreeEditableSelection: false)
                  : c)
              .toList();
          return TransactionOutcome(
            WalletData(
              schemaVersion: walletSchemaVersion,
              revision: insertedState.revision,
              settings: insertedState.settings,
              suppliers: insertedState.suppliers,
              cylinders: List<Cylinder>.unmodifiable(clearedSelections),
              events: insertedState.events,
              reminders: insertedState.reminders,
              pendingDraft: null,
              entitlementCache: verified,
            ),
            inserted.$2,
          );
        }
        final cylinders = isPro
            ? current.cylinders
                .map((c) => c.isFreeEditableSelection
                    ? c.copyWith(isFreeEditableSelection: false)
                    : c)
                .toList()
            : current.cylinders;
        return TransactionOutcome(current.next(
          cylinders: cylinders,
          entitlementCache: verified,
        ), null);
      });
  }

  Future<EditDecision> canEditCylinder(String cylinderId) async =>
      _editDecision(await repo.read(), cylinderId);

  Future<DowngradeDecision> enforceDowngradeIfNeeded() =>
      repo.transact((current) {
        if (current.entitlementCache.isProAt(clock.now())) {
          final cylinders = current.cylinders.map((c) => c.isFreeEditableSelection
              ? c.copyWith(isFreeEditableSelection: false) : c).toList();
          final changed = cylinders.indexed.any(
              (pair) => !identical(pair.$2, current.cylinders[pair.$1]));
          return TransactionOutcome(
            changed ? current.next(cylinders: cylinders) : current,
            const DowngradeReady(),
          );
        }
        final active = current.cylinders.where((c) => c.consumesCurrentSlot).toList();
        if (active.length <= freeEditableCylinderLimit) {
          final activeIds = active.map((c) => c.id).toSet();
          final cylinders = current.cylinders.map((c) => c.copyWith(
            isFreeEditableSelection: activeIds.contains(c.id),
          )).toList();
          return TransactionOutcome(
            current.next(cylinders: cylinders), const DowngradeReady());
        }
        final selected = active.where((c) => c.isFreeEditableSelection).length;
        return TransactionOutcome(
          current,
          selected <= freeEditableCylinderLimit && selected > 0
              ? const DowngradeReady()
              : const RequiresFreeSelection(freeEditableCylinderLimit),
        );
      });

  EditDecision _editDecision(WalletData state, String cylinderId) {
    final target = state.cylinders.where((c) => c.id == cylinderId).firstOrNull;
    if (target == null) return const MissingCylinder();
    if (state.entitlementCache.isProAt(clock.now())) return const Editable();
    if (!target.consumesCurrentSlot) return const Editable();
    final currentCount = state.cylinders.where((c) => c.consumesCurrentSlot).length;
    if (currentCount <= freeEditableCylinderLimit || target.isFreeEditableSelection) {
      return const Editable();
    }
    return const Locked(PaywallReason.editLockedCylinderAfterDowngrade);
  }

  Future<void> selectFreeEditable(
    Set<String> cylinderIds, {
    int? expectedRevision,
  }) =>
      repo.transact((current) {
        if (current.entitlementCache.isProAt(clock.now())) {
          return TransactionOutcome(
            current.next(cylinders: current.cylinders
                .map((c) => c.copyWith(isFreeEditableSelection: false)).toList()),
            null,
          );
        }
        if (cylinderIds.length > freeEditableCylinderLimit) {
          throw ArgumentError('Select at most $freeEditableCylinderLimit cylinders.');
        }
        final currentIds = current.cylinders
            .where((c) => c.consumesCurrentSlot).map((c) => c.id).toSet();
        if (!currentIds.containsAll(cylinderIds)) {
          throw ArgumentError('Selection contains a non-current cylinder.');
        }
        return TransactionOutcome(
          current.next(cylinders: current.cylinders.map((c) => c.copyWith(
            isFreeEditableSelection: cylinderIds.contains(c.id),
          )).toList()),
          null,
        );
      }, expectedRevision: expectedRevision);

  Future<void> recordExchange({
    required String cylinderId,
    required DateTime occurredAt,
    String? supplierId,
    Money? amount,
    FieldPatch<String> newSerialNumber = const Keep(),
    String? note,
    int? expectedRevision,
  }) =>
      repo.transact((current) {
        _requireEditable(current, cylinderId);
        _assertSupplierExists(current, supplierId);
        final index = current.cylinders.indexWhere((c) => c.id == cylinderId);
        final old = current.cylinders[index];
        final supplierPatch = supplierId == null
            ? const Keep<String>() : SetValue(_requiredText(supplierId, 'supplierId'));
        final updated = old.copyWith(
          serialNumber: newSerialNumber,
          supplierId: supplierPatch,
          lifecycle: CylinderLifecycle.exchanged,
          updatedAt: clock.now().toUtc(),
        );
        final cylinders = [...current.cylinders]..[index] = updated;
        final serial = newSerialNumber.apply(old.serialNumber);
        final event = CylinderEvent(
          id: ids.newId(), cylinderId: cylinderId,
          type: CylinderEventType.exchange, occurredAt: occurredAt.toUtc(),
          supplierId: supplierId ?? old.supplierId, amount: amount,
          note: _textOrNull(note), metadata: {'serialNumber': serial},
        );
        return TransactionOutcome(
          current.next(cylinders: cylinders, events: [...current.events, event]), null);
      }, expectedRevision: expectedRevision);

  Future<void> recordRefill({
    required String cylinderId,
    required DateTime occurredAt,
    FieldPatch<String> supplierId = const Keep(),
    Money? amount,
    String? note,
    int? expectedRevision,
  }) =>
      repo.transact((current) {
        _requireEditable(current, cylinderId);
        if (supplierId is SetValue<String>) {
          _assertSupplierExists(current, supplierId.value);
        }
        final index = current.cylinders.indexWhere((c) => c.id == cylinderId);
        final old = current.cylinders[index];
        final updated = old.copyWith(
          supplierId: supplierId,
          updatedAt: clock.now().toUtc(),
        );
        final cylinders = [...current.cylinders]..[index] = updated;
        final event = CylinderEvent(
          id: ids.newId(), cylinderId: cylinderId,
          type: CylinderEventType.refill, occurredAt: occurredAt.toUtc(),
          supplierId: updated.supplierId, amount: amount, note: _textOrNull(note),
        );
        return TransactionOutcome(
          current.next(cylinders: cylinders, events: [...current.events, event]), null);
      }, expectedRevision: expectedRevision);

  Future<void> changeSupplier({
    required String cylinderId,
    required FieldPatch<String> supplierId,
    required DateTime occurredAt,
    int? expectedRevision,
  }) =>
      repo.transact((current) {
        _requireEditable(current, cylinderId);
        if (supplierId is SetValue<String>) {
          _assertSupplierExists(current, supplierId.value);
        }
        final index = current.cylinders.indexWhere((c) => c.id == cylinderId);
        final old = current.cylinders[index];
        final updated = old.copyWith(
          supplierId: supplierId,
          updatedAt: clock.now().toUtc(),
        );
        final cylinders = [...current.cylinders]..[index] = updated;
        final event = CylinderEvent(
          id: ids.newId(), cylinderId: cylinderId,
          type: CylinderEventType.supplierChanged, occurredAt: occurredAt.toUtc(),
          supplierId: updated.supplierId,
          metadata: {'cleared': updated.supplierId == null},
        );
        return TransactionOutcome(
          current.next(cylinders: cylinders, events: [...current.events, event]), null);
      }, expectedRevision: expectedRevision);

  Future<void> recordCost({
    required String cylinderId,
    required DateTime occurredAt,
    required Money amount,
    String? supplierId,
    String? note,
    int? expectedRevision,
  }) =>
      repo.transact((current) {
        _requireEditable(current, cylinderId);
        _assertSupplierExists(current, supplierId);
        final event = CylinderEvent(
          id: ids.newId(), cylinderId: cylinderId, type: CylinderEventType.cost,
          occurredAt: occurredAt.toUtc(), supplierId: _textOrNull(supplierId),
          amount: amount, note: _textOrNull(note),
        );
        return TransactionOutcome(current.next(events: [...current.events, event]), null);
      }, expectedRevision: expectedRevision);

  Future<void> changeRelationship({
    required String cylinderId,
    required RelationshipType relationship,
    required DateTime occurredAt,
    String? note,
    int? expectedRevision,
  }) =>
      repo.transact((current) {
        _requireEditable(current, cylinderId);
        final index = current.cylinders.indexWhere((c) => c.id == cylinderId);
        final old = current.cylinders[index];
        final updated = old.copyWith(
          relationship: relationship,
          updatedAt: clock.now().toUtc(),
        );
        final cylinders = [...current.cylinders]..[index] = updated;
        final event = CylinderEvent(
          id: ids.newId(), cylinderId: cylinderId,
          type: CylinderEventType.relationshipChanged,
          occurredAt: occurredAt.toUtc(), note: _textOrNull(note),
          metadata: {'relationship': relationship.name},
        );
        return TransactionOutcome(
          current.next(cylinders: cylinders, events: [...current.events, event]), null);
      }, expectedRevision: expectedRevision);

  Future<void> markReturned(
    String cylinderId, {
    String? note,
    int? expectedRevision,
  }) => _transitionLifecycle(
        cylinderId: cylinderId,
        lifecycle: CylinderLifecycle.returned,
        eventType: CylinderEventType.returned,
        note: note,
        expectedRevision: expectedRevision,
      );

  Future<void> archiveCylinder(
    String cylinderId, {
    int? expectedRevision,
  }) => _transitionLifecycle(
        cylinderId: cylinderId,
        lifecycle: CylinderLifecycle.archived,
        eventType: CylinderEventType.archived,
        expectedRevision: expectedRevision,
      );

  Future<void> deleteCylinder(
    String cylinderId, {
    required bool confirmed,
    int? expectedRevision,
  }) async {
    if (!confirmed) throw StateError('Explicit confirmation is required.');
    final before = await repo.read();
    if (!before.cylinders.any((c) => c.id == cylinderId)) {
      throw StateError('Cylinder not found.');
    }
    // Notifications are external side effects. Cancel them first; if any
    // cancellation fails, retain the complete recoverable record.
    for (final reminder
        in before.reminders.where((r) => r.cylinderId == cylinderId)) {
      await scheduler.cancel(reminder.id);
    }
    await repo.transact((current) {
      if (!current.cylinders.any((c) => c.id == cylinderId)) {
        throw StateError('Cylinder not found.');
      }
      return TransactionOutcome(
        current.next(
          cylinders:
              current.cylinders.where((c) => c.id != cylinderId).toList(),
          events: current.events.where((e) => e.cylinderId != cylinderId).toList(),
          reminders:
              current.reminders.where((r) => r.cylinderId != cylinderId).toList(),
        ),
        null,
      );
    }, expectedRevision: expectedRevision);
    if (repo case ResidualWalletDataPurger purger) {
      await purger.purgeResidualWalletFiles();
    }
  }

  Future<void> _transitionLifecycle({
    required String cylinderId,
    required CylinderLifecycle lifecycle,
    required CylinderEventType eventType,
    String? note,
    int? expectedRevision,
  }) =>
      repo.transact((current) {
        _requireEditable(current, cylinderId);
        final index = current.cylinders.indexWhere((c) => c.id == cylinderId);
        final old = current.cylinders[index];
        final now = clock.now().toUtc();
        final updated = old.copyWith(
          lifecycle: lifecycle,
          updatedAt: now,
          isFreeEditableSelection: false,
        );
        final cylinders = [...current.cylinders]..[index] = updated;
        final event = CylinderEvent(
          id: ids.newId(), cylinderId: cylinderId, type: eventType,
          occurredAt: now, note: _textOrNull(note),
        );
        return TransactionOutcome(
          current.next(cylinders: cylinders, events: [...current.events, event]), null);
      }, expectedRevision: expectedRevision);

  Future<void> updateCylinderDetails({
    required String cylinderId,
    String? nickname,
    String? gasType,
    FieldPatch<double> capacityValue = const Keep(),
    FieldPatch<String> capacityUnit = const Keep(),
    FieldPatch<String> serialNumber = const Keep(),
    FieldPatch<String> localPhotoUri = const Keep(),
    FieldPatch<Money> acquisitionAmount = const Keep(),
    FieldPatch<DateTime> acquiredAt = const Keep(),
    RelationshipType? relationship,
    FieldPatch<String> supplierId = const Keep(),
    int? expectedRevision,
  }) =>
      repo.transact((current) {
        _requireEditable(current, cylinderId);
        if (supplierId is SetValue<String>) {
          _assertSupplierExists(current, supplierId.value);
        }
        final index = current.cylinders.indexWhere((c) => c.id == cylinderId);
        final old = current.cylinders[index];
        final now = clock.now().toUtc();
        final updated = old.copyWith(
          nickname: nickname == null ? null : _requiredText(nickname, 'nickname'),
          gasType: gasType == null ? null : _requiredText(gasType, 'gasType'),
          capacityValue: capacityValue,
          capacityUnit: capacityUnit,
          serialNumber: serialNumber,
          localPhotoUri: localPhotoUri,
          acquisitionAmount: acquisitionAmount,
          acquiredAt: acquiredAt,
          relationship: relationship,
          supplierId: supplierId,
          updatedAt: now,
        );
        if (updated.capacityValue != null &&
            (!updated.capacityValue!.isFinite || updated.capacityValue! <= 0)) {
          throw ArgumentError('Capacity must be a finite number above zero.');
        }
        if (updated.capacityValue != null && _textOrNull(updated.capacityUnit) == null) {
          throw ArgumentError('Capacity unit is required with capacity.');
        }
        final cylinders = [...current.cylinders]..[index] = updated;
        final events = [...current.events];
        if (acquisitionAmount is! Keep<Money> || acquiredAt is! Keep<DateTime>) {
          final acquisitionIndex = events.indexWhere(
            (event) =>
                event.cylinderId == cylinderId &&
                event.type == CylinderEventType.created,
          );
          if (acquisitionIndex >= 0) {
            final oldEvent = events[acquisitionIndex];
            events[acquisitionIndex] = CylinderEvent(
              id: oldEvent.id,
              cylinderId: oldEvent.cylinderId,
              type: oldEvent.type,
              occurredAt: updated.acquiredAt?.toUtc() ?? old.createdAt.toUtc(),
              supplierId: oldEvent.supplierId,
              amount: updated.acquisitionAmount,
              note: oldEvent.note,
              metadata: oldEvent.metadata,
            );
          }
        }
        if (updated.relationship != old.relationship) {
          events.add(CylinderEvent(
            id: ids.newId(),
            cylinderId: cylinderId,
            type: CylinderEventType.relationshipChanged,
            occurredAt: now,
            metadata: {'relationship': updated.relationship.name},
          ));
        }
        if (updated.supplierId != old.supplierId) {
          events.add(CylinderEvent(
            id: ids.newId(),
            cylinderId: cylinderId,
            type: CylinderEventType.supplierChanged,
            occurredAt: now,
            supplierId: updated.supplierId,
            metadata: {'cleared': updated.supplierId == null},
          ));
        }
        return TransactionOutcome(
          current.next(cylinders: cylinders, events: events),
          null,
        );
      }, expectedRevision: expectedRevision);

  Future<ReminderResult> createReminder({
    required String cylinderId,
    required ReminderKind kind,
    required String title,
    required DateTime dueAt,
    int? expectedRevision,
  }) async {
    final reminder = await repo.transact((current) {
      _requireEditable(current, cylinderId);
      final now = clock.now().toUtc();
      final created = Reminder(
        id: ids.newId(), cylinderId: cylinderId, kind: kind,
        title: _requiredText(title, 'title'), dueAt: dueAt.toUtc(), createdAt: now,
        delivery: current.settings.remindersEnabled
            ? ReminderDelivery.needsScheduling : ReminderDelivery.idle,
      );
      final event = CylinderEvent(
        id: ids.newId(), cylinderId: cylinderId,
        type: CylinderEventType.reminderCreated, occurredAt: now,
        metadata: {'reminderId': created.id, 'dueAt': created.dueAt.toIso8601String()},
      );
      return TransactionOutcome(current.next(
        reminders: [...current.reminders, created],
        events: [...current.events, event],
      ), created);
    }, expectedRevision: expectedRevision);
    if (!(await repo.read()).settings.remindersEnabled) {
      return ReminderResult(reminder, false);
    }
    try {
      await scheduler.schedule(reminder);
      await _setReminderDelivery(reminder.id, ReminderDelivery.scheduled);
      return ReminderResult(reminder, true);
    } catch (_) {
      // Durable reminder remains marked needsScheduling for app-resume repair.
      return ReminderResult(reminder, false);
    }
  }

  Future<void> completeReminder(String reminderId, {int? expectedRevision}) async {
    final completed = await repo.transact((current) {
      final index = current.reminders.indexWhere((r) => r.id == reminderId);
      if (index < 0) throw StateError('Reminder not found.');
      final old = current.reminders[index];
      _requireEditable(current, old.cylinderId);
      final updated = old.copyWith(
        completed: true, delivery: ReminderDelivery.needsCancellation);
      final reminders = [...current.reminders]..[index] = updated;
      final event = CylinderEvent(
        id: ids.newId(), cylinderId: old.cylinderId,
        type: CylinderEventType.reminderCompleted,
        occurredAt: clock.now().toUtc(), metadata: {'reminderId': reminderId},
      );
      return TransactionOutcome(current.next(
        reminders: reminders, events: [...current.events, event]), updated);
    }, expectedRevision: expectedRevision);
    try {
      await scheduler.cancel(completed.id);
      await _setReminderDelivery(completed.id, ReminderDelivery.idle);
    } catch (_) {
      // Reconciliation will retry; the domain completion itself is committed.
    }
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    await repo.transact((current) => TransactionOutcome(
      current.next(settings: current.settings.copyWith(remindersEnabled: enabled),
          reminders: current.reminders.map((r) => r.completed
              ? r.copyWith(delivery: ReminderDelivery.needsCancellation)
              : r.copyWith(delivery: enabled
                  ? ReminderDelivery.needsScheduling : ReminderDelivery.needsCancellation))
              .toList()),
      null,
    ));
    await reconcileReminders();
  }

  Future<void> reconcileReminders() async {
    final current = await repo.read();
    for (final reminder in current.reminders) {
      try {
        if (!current.settings.remindersEnabled || reminder.completed) {
          if (reminder.delivery != ReminderDelivery.idle) {
            await scheduler.cancel(reminder.id);
            await _setReminderDelivery(reminder.id, ReminderDelivery.idle);
          }
        } else if (reminder.delivery != ReminderDelivery.scheduled) {
          await scheduler.schedule(reminder);
          await _setReminderDelivery(reminder.id, ReminderDelivery.scheduled);
        }
      } catch (_) {
        // Keep the pending state for the next app resume.
      }
    }
  }

  Future<void> _setReminderDelivery(String id, ReminderDelivery delivery) =>
      repo.transact((current) {
        final index = current.reminders.indexWhere((r) => r.id == id);
        if (index < 0) return TransactionOutcome(current, null);
        final reminders = [...current.reminders]
          ..[index] = current.reminders[index].copyWith(delivery: delivery);
        return TransactionOutcome(current.next(reminders: reminders), null);
      });

  Future<String> exportBackup() async => BackupCodec.encode(await repo.read(), clock.now());

  Future<Map<String, int>> spendByCurrency({
    DateTime? from,
    DateTime? to,
    String? cylinderId,
  }) async {
    final state = await repo.read();
    final totals = <String, int>{};
    for (final event in state.events) {
      final amount = event.amount;
      if (amount == null || (cylinderId != null && event.cylinderId != cylinderId)) {
        continue;
      }
      if (from != null && event.occurredAt.isBefore(from.toUtc())) continue;
      if (to != null && event.occurredAt.isAfter(to.toUtc())) continue;
      // A returned deposit is money back to the user, so it reduces net outlay.
      // All other recorded amounts are outflows. Currencies remain separate.
      final signedMinorUnits = event.type == CylinderEventType.depositReturned
          ? -amount.minorUnits
          : amount.minorUnits;
      totals.update(amount.currencyCode, (value) => value + signedMinorUnits,
          ifAbsent: () => signedMinorUnits);
    }
    // Never auto-convert currencies without an explicit user-approved FX source.
    return Map<String, int>.unmodifiable(totals);
  }

  Future<WalletData> importBackup(String encoded, {required int expectedRevision}) async {
    final imported = BackupCodec.decode(encoded);
    final before = await repo.read();
    // Entitlements are never accepted from a file; retain store-derived cache.
    final safe = WalletData(
      schemaVersion: walletSchemaVersion,
      revision: before.revision + 1,
      settings: imported.settings,
      suppliers: imported.suppliers,
      cylinders: imported.cylinders,
      events: imported.events,
      reminders: imported.reminders.map((r) => r.copyWith(
        delivery: r.completed
            ? ReminderDelivery.needsCancellation
            : ReminderDelivery.needsScheduling,
      )).toList(),
      pendingDraft: imported.pendingDraft,
      entitlementCache: before.entitlementCache,
    );
    final replaced = await repo.replaceFromBackup(safe, expectedRevision: expectedRevision);
    await reconcileReminders();
    return replaced;
  }

  Future<void> deleteAllWalletData({required bool confirmed}) async {
    if (!confirmed) throw StateError('Explicit confirmation is required.');
    // Cancel first. If it fails, retain the recoverable data instead of leaving
    // untraceable notifications behind.
    await scheduler.cancelAll();
    await repo.transact((current) {
      final cleared = WalletData.empty(
        locale: current.settings.locale,
        currencyCode: current.settings.currencyCode,
      );
      return TransactionOutcome(WalletData(
        schemaVersion: walletSchemaVersion,
        revision: current.revision + 1,
        settings: cleared.settings,
        suppliers: const [],
        cylinders: const [], events: const [], reminders: const [],
        pendingDraft: null,
        entitlementCache: current.entitlementCache,
      ), null);
    });
    if (repo case ResidualWalletDataPurger purger) {
      await purger.purgeResidualWalletFiles();
    }
  }

  void _requireEditable(WalletData state, String cylinderId) {
    final decision = _editDecision(state, cylinderId);
    if (decision is MissingCylinder) throw StateError('Cylinder not found.');
    if (decision is Locked) throw StateError('Cylinder is read-only.');
  }

  void _assertSupplierExists(WalletData state, String? supplierId) {
    final id = _textOrNull(supplierId);
    if (id != null && !state.suppliers.any((s) => s.id == id)) {
      throw ArgumentError('Supplier does not exist.');
    }
  }

  void _validateVerifiedEntitlement(Entitlement entitlement) {
    if (entitlement.tier == AccessTier.free &&
        entitlement.source != EntitlementSource.none) {
      throw StateError('Free entitlement has an invalid source.');
    }
    if (entitlement.tier == AccessTier.pro) {
      final expected = billing.platform == StorePlatform.android
          ? EntitlementSource.googlePlaySubscription
          : EntitlementSource.appStoreLifetime;
      if (entitlement.source != expected) {
        throw StateError('Verified entitlement source does not match platform.');
      }
      if (expected == EntitlementSource.googlePlaySubscription &&
          entitlement.validUntil == null) {
        throw StateError('Android subscription is missing expiry.');
      }
    }
  }

  void _validateDraft(AddCylinderDraft draft) {
    _requiredText(draft.nickname, 'nickname');
    _requiredText(draft.gasType, 'gasType');
    if (draft.capacityValue != null &&
        (!draft.capacityValue!.isFinite || draft.capacityValue! <= 0)) {
      throw ArgumentError('Capacity must be a finite number above zero.');
    }
    if (draft.capacityValue != null && _textOrNull(draft.capacityUnit) == null) {
      throw ArgumentError('Capacity unit is required with capacity.');
    }
  }
}

class BackupCodec {
  static const format = 'welding-gas-wallet';

  static String encode(WalletData state, DateTime exportedAt) {
    final payload = state.backupPayload();
    final payloadText = jsonEncode(payload);
    return jsonEncode({
      'format': format,
      'schemaVersion': walletSchemaVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'checksum': _crc32(payloadText),
      'payload': payload,
    });
  }

  static WalletData decode(String encoded) {
    if (utf8.encode(encoded).length > maximumBackupBytes) {
      throw const FormatException('Backup exceeds 5 MB.');
    }
    final rootRaw = jsonDecode(encoded);
    if (rootRaw is! Map<Object?, Object?>) {
      throw const FormatException('Backup must be an object.');
    }
    final root = Map<String, Object?>.from(rootRaw);
    if (root['format'] != format) throw const FormatException('Unknown backup format.');
    final version = (root['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version < 1 || version > walletSchemaVersion) {
      throw FormatException('Unsupported backup schema $version.');
    }
    if (root['payload'] is! Map<Object?, Object?>) {
      throw const FormatException('Missing payload.');
    }
    var payload = Map<String, Object?>.from(
      root['payload']! as Map<Object?, Object?>,
    );
    final checksum = root['checksum']?.toString();
    if (checksum == null || checksum != _crc32(jsonEncode(payload))) {
      throw const FormatException('Backup checksum does not match.');
    }
    if (version == 1) payload = _migrateV1(payload);
    final state = _stateFromPayload(payload);
    _validateImportedState(state);
    return state;
  }

  static Map<String, Object?> _migrateV1(Map<String, Object?> old) => {
        'settings': old['settings'] ?? <String, Object?>{},
        'suppliers': old['suppliers'] ?? const [],
        'cylinders': old['cylinders'] ?? const [],
        'events': old['events'] ?? const [],
        'reminders': old['reminders'] ?? const [],
        'pendingDraft': old['pendingDraft'],
      };

  static WalletData _stateFromPayload(Map<String, Object?> payload) {
    List<Map<String, Object?>> maps(Object? raw, String name) {
      if (raw is! List<Object?>) throw FormatException('$name must be a list.');
      return raw.map((v) {
        if (v is! Map<Object?, Object?>) {
          throw FormatException('$name contains an invalid item.');
        }
        return Map<String, Object?>.from(v);
      }).toList();
    }

    final settingsRaw = payload['settings'];
    if (settingsRaw is! Map<Object?, Object?>) {
      throw const FormatException('Missing settings.');
    }
    return WalletData(
      schemaVersion: walletSchemaVersion,
      revision: 0,
      settings: AppSettings.fromJson(Map<String, Object?>.from(settingsRaw)),
      suppliers: maps(payload['suppliers'] ?? const [], 'suppliers')
          .map(Supplier.fromJson).toList(),
      cylinders: maps(payload['cylinders'], 'cylinders').map(Cylinder.fromJson).toList(),
      events: maps(payload['events'], 'events').map(CylinderEvent.fromJson).toList(),
      reminders: maps(payload['reminders'], 'reminders').map(Reminder.fromJson).toList(),
      pendingDraft: payload['pendingDraft'] is Map<Object?, Object?>
          ? AddCylinderDraft.fromJson(
              Map<String, Object?>.from(
                payload['pendingDraft']! as Map<Object?, Object?>))
          : null,
      entitlementCache: const Entitlement.free(),
    );
  }

  static void _validateImportedState(WalletData state) {
    if (state.suppliers.length > 10000 || state.cylinders.length > 10000 ||
        state.events.length > 100000 || state.reminders.length > 50000) {
      throw const FormatException('Backup item count exceeds safe limits.');
    }
    final supplierIds = <String>{};
    for (final supplier in state.suppliers) {
      if (supplier.id.trim().isEmpty || !supplierIds.add(supplier.id)) {
        throw const FormatException('Supplier IDs must be non-empty and unique.');
      }
      _requiredText(supplier.name, 'supplier name');
    }
    final cylinderIds = <String>{};
    for (final c in state.cylinders) {
      if (c.id.trim().isEmpty || !cylinderIds.add(c.id)) {
        throw const FormatException('Cylinder IDs must be non-empty and unique.');
      }
      _requiredText(c.nickname, 'nickname');
      _requiredText(c.gasType, 'gasType');
      if (c.capacityValue != null &&
          (!c.capacityValue!.isFinite || c.capacityValue! <= 0)) {
        throw const FormatException('Invalid cylinder capacity.');
      }
      if (c.supplierId != null && !supplierIds.contains(c.supplierId)) {
        throw const FormatException('Cylinder references an unknown supplier.');
      }
    }
    final eventIds = <String>{};
    for (final e in state.events) {
      if (!eventIds.add(e.id) || !cylinderIds.contains(e.cylinderId)) {
        throw const FormatException('Invalid or orphaned event.');
      }
      if (e.id.trim().isEmpty ||
          (e.supplierId != null && !supplierIds.contains(e.supplierId))) {
        throw const FormatException('Event references invalid data.');
      }
    }
    final reminderIds = <String>{};
    for (final r in state.reminders) {
      if (!reminderIds.add(r.id) || !cylinderIds.contains(r.cylinderId)) {
        throw const FormatException('Invalid or orphaned reminder.');
      }
      if (r.id.trim().isEmpty) {
        throw const FormatException('Reminder ID must not be empty.');
      }
      _requiredText(r.title, 'reminder title');
    }
    if (state.pendingDraft != null) {
      _requiredText(state.pendingDraft!.nickname, 'nickname');
      _requiredText(state.pendingDraft!.gasType, 'gasType');
      final supplierId = state.pendingDraft!.supplierId;
      if (supplierId != null && !supplierIds.contains(supplierId)) {
        throw const FormatException('Pending draft references an unknown supplier.');
      }
    }
  }

  static String _crc32(String input) {
    var crc = 0xffffffff;
    for (final byte in utf8.encode(input)) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return ((crc ^ 0xffffffff) & 0xffffffff)
        .toRadixString(16).padLeft(8, '0');
  }
}

String _requiredText(String value, String field) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) throw ArgumentError('$field is required.');
  if (trimmed.length > 500) throw ArgumentError('$field is too long.');
  return trimmed;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

class SafetyGuard {
  static const forbiddenAutomatedClaims = <String>[
    'you legally own this cylinder', 'this cylinder is safe',
    'this cylinder is safe to fill', 'this cylinder is eligible for refill',
    'this cylinder passes inspection', 'this test mark is valid',
    'this cylinder complies with local law',
    'this supplier must accept this cylinder',
  ];

  static bool isAllowedUserFacingConclusion(String text) {
    final normalized = text.trim().toLowerCase();
    return !forbiddenAutomatedClaims.any(normalized.contains);
  }
}
