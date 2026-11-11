import 'package:submersion/core/geography/country_names.generated.dart';
import 'package:submersion/core/text/text_sort.dart';

/// Names divers use that CLDR does not list, each with one unambiguous
/// country (issue #4426). Keyed by [countryLookupKey]; CLDR's own names in
/// every place-name language and each country's official languages live in
/// the generated table.
const Map<String, String> _aliases = {
  'usa': 'US',
  'united states of america': 'US',
  'uae': 'AE',
  'dr congo': 'CD',
  'drc': 'CD',
  'england': 'GB',
  'scotland': 'GB',
  'wales': 'GB',
  'northern ireland': 'GB',
  'great britain': 'GB',
  'holland': 'NL',
  'bonaire': 'BQ',
  'sint eustatius': 'BQ',
  'saba': 'BQ',
  'turks and caicos': 'TC',
  'czech republic': 'CZ',
  // The Maldives in Dhivehi: CLDR ships no Dhivehi locale data.
  'ދިވެހިރާއްޖެ': 'MV',
};

/// The key a country name is looked up by: [textSortKey]'s case and accent
/// fold, with periods removed ("U.S.A." reads as "USA"), "&" read as "and"
/// ("Trinidad & Tobago"), runs of whitespace collapsed, and a leading
/// "the " dropped ("The Bahamas").
///
/// scripts/geography/generate_country_names.py folds the generated table's
/// names the same way.
String countryLookupKey(String text) {
  final key = textSortKey(text)
      .replaceAll('.', '')
      .replaceAll('&', ' and ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .join(' ');
  return key.startsWith('the ') ? key.substring(4) : key;
}

/// The ISO 3166-1 alpha-2 code a site's free-text [text] names, or null.
///
/// Accepts an alpha-2 or alpha-3 code, a country's name in any of the app's
/// place-name languages or in its own official languages, and a few common
/// aliases ("UK", "Holland"). Only whole, exact (folded) names match: "Gulf
/// of Mexico" and "Mexico City" give null, because a missing flag is better
/// than a wrong one.
String? countryCodeFor(String? text) {
  if (text == null) return null;
  final key = countryLookupKey(text);
  if (key.isEmpty) return null;
  final upper = key.toUpperCase();
  if (key.length == 2 && assignedAlpha2Codes.contains(upper)) return upper;
  if (key.length == 3) {
    final fromAlpha3 = alpha3ToAlpha2[upper];
    if (fromAlpha3 != null) return fromAlpha3;
  }
  return _aliases[key] ?? cldrCountryNameCodes[key];
}
