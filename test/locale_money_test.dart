import 'package:flutter_test/flutter_test.dart';
import 'package:welding_gas_wallet/src/locale_money.dart';

void main() {
  test('CLDR territory currency is preserved before catalog canonicalization',
      () {
    const expected = <String, String>{
      'en_US': 'USD',
      'en_GB': 'GBP',
      'en_CA': 'CAD',
      'en_AU': 'AUD',
      'en_NZ': 'NZD',
      'en_IE': 'EUR',
      'en_IN': 'INR',
      'en_ZA': 'ZAR',
      'en_SG': 'SGD',
      'es_ES': 'EUR',
      'es_MX': 'MXN',
      'es_AR': 'ARS',
      'es_CL': 'CLP',
      'es_CO': 'COP',
      'es_PE': 'PEN',
      'es_US': 'USD',
      'pt_BR': 'BRL',
      'pt_PT': 'EUR',
      'pt_AO': 'AOA',
      'pt_MZ': 'MZN',
      'fr_FR': 'EUR',
      'fr_CA': 'CAD',
      'fr_CH': 'CHF',
      'de_CH': 'CHF',
      'it_CH': 'CHF',
      'sv_FI': 'EUR',
      'ro_MD': 'MDL',
      'zh_CN': 'CNY',
      'zh_SG': 'SGD',
      'zh_TW': 'TWD',
      'zh_HK': 'HKD',
      'zh_MO': 'MOP',
      'ar_AE': 'AED',
      'ar_SA': 'SAR',
      'ar_EG': 'EGP',
      'ar_MA': 'MAD',
      'ar_DZ': 'DZD',
      'ar_QA': 'QAR',
      'ar_KW': 'KWD',
      'ar_BH': 'BHD',
      'ar_OM': 'OMR',
      'ar_JO': 'JOD',
      'bn_BD': 'BDT',
      'bn_IN': 'INR',
      'ms_MY': 'MYR',
      'ms_BN': 'BND',
      'ms_SG': 'SGD',
    };
    for (final entry in expected.entries) {
      expect(
        LocaleMoney.defaultCurrencyForSystemLocale(entry.key),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('parses comma-decimal and grouping using selected app locale', () {
    expect(LocaleMoney.parseMajor('1.234,56', 'de'), 1234.56);
    expect(LocaleMoney.parseMajor('1 234,56', 'fr'), 1234.56);
    expect(LocaleMoney.parseMajor('1,234.56', 'en'), 1234.56);
  });

  test('parses RTL Arabic digits and separators without changing value', () {
    expect(LocaleMoney.parseMajor('١٬٢٣٤٫٥٠', 'ar'), 1234.5);
    final money = LocaleMoney.parseMoney('١٢٫٣٤', 'USD', 'ar');
    expect(money?.minorUnits, 1234);
  });

  test('respects ISO zero, two, three and four decimal minor-unit scales', () {
    expect(LocaleMoney.currencyScale('JPY'), 0);
    expect(LocaleMoney.currencyScale('USD'), 2);
    expect(LocaleMoney.currencyScale('KWD'), 3);
    expect(LocaleMoney.currencyScale('CLF'), 4);
    expect(LocaleMoney.parseMoney('1234', 'JPY', 'en')?.minorUnits, 1234);
    expect(LocaleMoney.parseMoney('12.34', 'USD', 'en')?.minorUnits, 1234);
    expect(LocaleMoney.parseMoney('1.234', 'KWD', 'en')?.minorUnits, 1234);
    expect(LocaleMoney.parseMoney('1.2345', 'CLF', 'en')?.minorUnits, 12345);
  });

  test('formatting uses selected locale explicitly', () {
    final german = LocaleMoney.formatMinorUnits(123456, 'EUR', 'de');
    final english = LocaleMoney.formatMinorUnits(123456, 'EUR', 'en');
    expect(german, contains(','));
    expect(english, contains('.'));
    expect(german, isNot(english));

    expect(LocaleMoney.formatMinorUnits(1234, 'JPY', 'ja'), isNot(contains('.')));
    expect(LocaleMoney.formatMinorUnits(1234, 'KWD', 'ar'), isNotEmpty);
  });
}
