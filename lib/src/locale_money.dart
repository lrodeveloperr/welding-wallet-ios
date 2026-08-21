import 'package:intl/intl.dart';

import 'domain/welding_gas_wallet_core_v1_1.dart';

abstract final class LocaleMoney {
  static String intlLocale(String locale) =>
      Intl.canonicalizedLocale(canonicalLocale(locale).replaceAll('-', '_'));

  static String defaultCurrencyForSystemLocale(String systemLocale) {
    try {
      final intlSystemLocale = Intl.canonicalizedLocale(
        systemLocale.trim().replaceAll('-', '_'),
      );
      final cldrCurrency = NumberFormat.simpleCurrency(
        locale: intlSystemLocale,
      ).currencyName;
      if (cldrCurrency != null && iso4217Codes.contains(cldrCurrency)) {
        return cldrCurrency;
      }
    } on Object {
      // An uncommon platform tag may be absent from the bundled CLDR data.
    }
    return defaultCurrencyForLocale(systemLocale);
  }

  static int currencyScale(String code) {
    if (const <String>{
      'BIF', 'CLP', 'DJF', 'GNF', 'ISK', 'JPY', 'KMF', 'KRW', 'PYG', 'RWF',
      'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF',
    }.contains(code)) {
      return 0;
    }
    if (const <String>{
      'BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND',
    }.contains(code)) {
      return 3;
    }
    if (const <String>{'CLF', 'UYW'}.contains(code)) return 4;
    return 2;
  }

  static double? parseMajor(String input, String locale) {
    var value = _normalizeDigits(input.trim());
    if (value.isEmpty) return null;
    final symbols = NumberFormat.decimalPattern(intlLocale(locale)).symbols;
    final decimal = symbols.DECIMAL_SEP;
    final group = symbols.GROUP_SEP;
    value = value
        .replaceAll('\u00a0', '')
        .replaceAll('\u202f', '')
        .replaceAll(' ', '')
        .replaceAll("'", '');
    if (group.isNotEmpty && group != decimal) value = value.replaceAll(group, '');
    if (decimal != '.') value = value.replaceAll(decimal, '.');
    return double.tryParse(value);
  }

  static Money? parseMoney(String input, String currencyCode, String locale) {
    if (input.trim().isEmpty) return null;
    final amount = parseMajor(input, locale);
    if (amount == null || !amount.isFinite || amount < 0) return null;
    final scale = currencyScale(currencyCode);
    return Money(
      minorUnits: (amount * _powerOfTen(scale)).round(),
      currencyCode: currencyCode,
    );
  }

  static String formatMoney(Money money, String locale) => formatMinorUnits(
        money.minorUnits,
        money.currencyCode,
        locale,
      );

  static String formatMinorUnits(
    int minorUnits,
    String currencyCode,
    String locale,
  ) {
    final scale = currencyScale(currencyCode);
    return NumberFormat.currency(
      locale: intlLocale(locale),
      name: currencyCode,
      symbol: '$currencyCode ',
      decimalDigits: scale,
    ).format(minorUnits / _powerOfTen(scale));
  }

  static String inputValue(
    int minorUnits,
    String currencyCode,
    String locale,
  ) {
    final scale = currencyScale(currencyCode);
    return NumberFormat.decimalPatternDigits(
      locale: intlLocale(locale),
      decimalDigits: scale,
    ).format(minorUnits / _powerOfTen(scale));
  }

  static String formatDecimal(double value, String locale) {
    final format = NumberFormat.decimalPattern(intlLocale(locale))
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = 2;
    return format.format(value);
  }

  static String _normalizeDigits(String value) {
    const zeroCodePoints = <int>[0x0660, 0x06f0, 0x0966, 0x09e6, 0x0e50];
    final output = StringBuffer();
    for (final rune in value.runes) {
      var translated = rune;
      for (final zero in zeroCodePoints) {
        if (rune >= zero && rune <= zero + 9) {
          translated = 0x30 + rune - zero;
          break;
        }
      }
      output.writeCharCode(translated);
    }
    return output.toString()
        .replaceAll('\u066b', '.')
        .replaceAll('\u066c', '');
  }

  static int _powerOfTen(int exponent) => switch (exponent) {
      0 => 1,
      3 => 1000,
      4 => 10000,
      _ => 100,
    };
}
