import 'package:intl/intl.dart';

/// Common currency codes offered as presets in pickers. Free-text entry still
/// allows any other ISO 4217 code.
const List<String> kCommonCurrencyCodes = [
  'USD',
  'EUR',
  'GBP',
  'CHF',
  'AUD',
  'CAD',
  'NZD',
  'JPY',
  'SEK',
  'NOK',
  'DKK',
  'THB',
  'EGP',
  'MXN',
  'IDR',
  'PHP',
  'ZAR',
];

/// The preset codes, with [currentCode] prepended when it is a real code
/// outside the presets. Free-text entry means a stored currency can be
/// anything; without this it would vanish from every picker that offers only
/// the presets, leaving the current value unselectable.
List<String> currencyCodesWith(String? currentCode) {
  final current = (currentCode ?? '').trim().toUpperCase();
  if (current.isEmpty || kCommonCurrencyCodes.contains(current)) {
    return kCommonCurrencyCodes;
  }
  return [current, ...kCommonCurrencyCodes];
}

/// The symbol for [currencyCode] (e.g. 'EUR' -> '€'), falling back to the
/// upper-cased code itself for anything intl doesn't recognise (or an empty
/// string for a blank code).
String currencySymbol(String currencyCode) {
  final code = currencyCode.trim().toUpperCase();
  if (code.isEmpty) return '';
  try {
    return NumberFormat.simpleCurrency(name: code).currencySymbol;
  } catch (_) {
    return code;
  }
}

/// Formats [amount] in [currencyCode] using the currency's symbol, falling back
/// to "CODE 12.34" for unrecognised codes.
String formatMoney(double amount, String currencyCode) {
  final code = currencyCode.trim().toUpperCase();
  try {
    return NumberFormat.simpleCurrency(name: code).format(amount);
  } catch (_) {
    final prefix = code.isEmpty ? '' : '$code ';
    return '$prefix${amount.toStringAsFixed(2)}';
  }
}

/// Sums the amounts in [items] grouped by their currency, so a collection
/// priced in more than one currency is never added into a single misleading
/// figure.
///
/// [amountOf] returns null for items with no price (those are skipped), and a
/// blank [currencyOf] falls back to [fallbackCode] - legacy rows can carry an
/// empty code. Entries come back ordered by descending total, then by code, so
/// the display order is stable across rebuilds.
List<MapEntry<String, double>> sumByCurrency<T>(
  Iterable<T> items, {
  required double? Function(T item) amountOf,
  required String Function(T item) currencyOf,
  required String fallbackCode,
}) {
  final fallback = fallbackCode.trim().toUpperCase();
  final totals = <String, double>{};
  for (final item in items) {
    final amount = amountOf(item);
    if (amount == null) continue;
    final raw = currencyOf(item).trim().toUpperCase();
    final code = raw.isEmpty ? fallback : raw;
    totals[code] = (totals[code] ?? 0) + amount;
  }
  final entries = totals.entries.toList()
    ..sort((a, b) {
      final byTotal = b.value.compareTo(a.value);
      return byTotal != 0 ? byTotal : a.key.compareTo(b.key);
    });
  return entries;
}
