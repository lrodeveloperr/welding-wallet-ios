import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:welding_gas_wallet/src/app_strings.dart';
import 'package:welding_gas_wallet/src/domain/welding_gas_wallet_core_v1_1.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 30 supported catalogs have exact 177-key parity', () async {
    final english = await _catalog('en');
    expect(english, hasLength(177));
    expect(localeNativeNames.keys.toSet(), supportedLocales.toSet());
    for (final locale in supportedLocales) {
      final catalog = await _catalog(locale);
      expect(
        catalog.keys.toSet(),
        english.keys.toSet(),
        reason: '$locale must neither omit keys nor silently merge English.',
      );
      expect(catalog, hasLength(177));
      for (final key in <String>[
        'annualPurchaseContract',
        'monthlyPurchaseContract',
        'lifetimePurchaseContract',
        'subscribeAnnualAction',
        'subscribeMonthlyAction',
        'buyLifetimeAction',
      ]) {
        expect(catalog[key], contains('{price}'), reason: '$locale $key');
      }
    }
  });

  test('strict loader opens every exact catalog without English fallback', () async {
    for (final locale in supportedLocales) {
      final strings = await AppStrings.load(locale);
      expect(strings.locale, locale);
      expect(strings('appName'), isNotEmpty);
    }
    expect((await AppStrings.load('unsupported')).locale, 'en');
  });

  test('RTL and Chinese script canonicalization are explicit', () async {
    expect((await AppStrings.load('ar')).isRtl, isTrue);
    expect((await AppStrings.load('en')).isRtl, isFalse);
    expect(canonicalLocale('zh-CN'), 'zh-Hans');
    expect(canonicalLocale('zh-TW'), 'zh-Hant');
  });

  test('compiled emergency recovery copy is exact and complete for 30 locales',
      () {
    for (final locale in supportedLocales) {
      final emergency = emergencyRecoveryForLocale(locale);
      expect(emergency.locale, locale);
      expect(emergency.title, isNotEmpty);
      expect(emergency.body, contains(locale));
      expect(emergency.body, isNot(contains('{locale}')));
      expect(emergency.retry, isNotEmpty);
    }
    expect(emergencyRecoveryForLocale('unsupported').locale, 'en');
  });

  test('non-English user-facing errors are catalog-derived', () async {
    final english = await AppStrings.load('en');
    final spanish = await AppStrings.load('es');
    for (final key in <String>[
      'notificationPermissionDenied',
      'linkUnavailable',
      'invalidBackup',
      'invalidValue',
      'walletChanged',
    ]) {
      expect(spanish(key), isNot(key));
      expect(spanish(key), isNot(english(key)), reason: key);
    }
  });
}

Future<Map<String, String>> _catalog(String locale) async {
  final asset = 'assets/l10n/app_${locale.replaceAll('-', '_')}.arb';
  final decoded = jsonDecode(await rootBundle.loadString(asset))
      as Map<String, Object?>;
  return <String, String>{
    for (final entry in decoded.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}
