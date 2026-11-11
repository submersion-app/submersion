import 'package:submersion/core/geography/country_names.generated.dart';
import 'package:submersion/core/text/text_sort.dart';

/// Names divers use that CLDR does not list, each with one unambiguous
/// country (issue #4426). Keyed by [countryLookupKey]; CLDR's own names in
/// every place-name language and each country's official languages live in
/// the generated table.
/// "USA" and "Czech Republic" need no entry: the alpha-3 code and CLDR's
/// own variant name already find them.
const Map<String, String> _aliases = {
  'united states of america': 'US',
  'uae': 'AE',
  'dr congo': 'CD',
  'drc': 'CD',
  // The formal English names: CLDR writes "Congo - Kinshasa", "St. Kitts &
  // Nevis" and "St. Vincent & Grenadines", and the site country field
  // suggests these (isoCountryNames).
  'democratic republic of the congo': 'CD',
  'republic of the congo': 'CG',
  'saint kitts and nevis': 'KN',
  'saint vincent and the grenadines': 'VC',
  'burma': 'MM',
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
  // The Maldives in Dhivehi: CLDR ships no Dhivehi locale data.
  'ދިވެހިރާއްޖެ': 'MV',
};

/// Latin letters past [textSortKey]'s table, mirrored by _WIDER_LATIN in
/// scripts/geography/generate_country_names.py: names in Central European
/// and Turkish spellings ("Česko", "Łódź") fold like their plain forms.
const Map<String, String> _widerLatin = {
  'ă': 'a', 'ą': 'a', 'ā': 'a', 'ć': 'c', 'č': 'c', 'ď': 'd', 'đ': 'd', //
  'ę': 'e', 'ě': 'e', 'ē': 'e', 'ğ': 'g', 'ı': 'i', 'ī': 'i', 'ł': 'l', //
  'ń': 'n', 'ň': 'n', 'ō': 'o', 'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's', //
  'ș': 's', 'ť': 't', 'ţ': 't', 'ț': 't', 'ū': 'u', 'ů': 'u', 'ź': 'z', //
  'ż': 'z', 'ž': 'z',
};

/// Punctuation people type in more than one way, mirrored by _PUNCTUATION in
/// scripts/geography/generate_country_names.py: a typed straight apostrophe
/// finds CLDR's curly one ("Cote d'Ivoire"), and a hyphen or dash reads as a
/// space ("Guinea Bissau", "Timor Leste").
const Map<String, String> _punctuation = {
  '’': "'", '‘': "'", 'ʼ': "'", '`': "'", //
  '-': ' ', '‐': ' ', '‑': ' ', '–': ' ',
};

/// Folded placeholder text that also happens to be a country code.
const Set<String> _placeholders = {'na'};

final RegExp _whitespace = RegExp(r'\s+');

/// The key a country name is looked up by: [textSortKey]'s case and accent
/// fold, with periods removed ("U.S.A." reads as "USA"), apostrophes made
/// straight, hyphens and dashes read as spaces, "&" read as "and"
/// ("Trinidad & Tobago"), runs of whitespace collapsed, and a leading
/// "the " dropped ("The Bahamas").
///
/// scripts/geography/generate_country_names.py folds the generated table's
/// names the same way.
String countryLookupKey(String text) {
  final folded = StringBuffer();
  for (final rune in textSortKey(text).runes) {
    // Decomposed accents ("e" + U+0301) drop their mark.
    if (rune >= 0x300 && rune <= 0x36F) continue;
    final char = String.fromCharCode(rune);
    folded.write(_widerLatin[char] ?? _punctuation[char] ?? char);
  }
  final key = folded
      .toString()
      .replaceAll('.', '')
      .replaceAll('&', ' and ')
      .split(_whitespace)
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
  // A list resolves the same few stored countries in every row it builds,
  // so each distinct text is folded once.
  if (_resolved.containsKey(text)) return _resolved[text];
  if (_resolved.length >= _maxResolved) _resolved.clear();
  return _resolved[text] = _resolve(text);
}

/// The code a site's flag is drawn for (issue #4426): its stored [code],
/// else the country its free-text [country] names, else null.
String? siteFlagCode({required String? country, required String? code}) =>
    code ?? countryCodeFor(country);

/// Stored country texts already resolved, bounded so a stream of distinct
/// texts (an import) cannot grow it without end.
final Map<String, String?> _resolved = {};
const int _maxResolved = 512;

String? _resolve(String text) {
  final key = countryLookupKey(text);
  if (key.isEmpty) return null;
  final upper = key.toUpperCase();
  // "NA" fills unknown cells in imports and spreadsheets far more often than
  // it names Namibia, so it is not read as a code; "Namibia" and "NAM" are.
  if (_placeholders.contains(key)) return null;
  if (key.length == 2 && assignedAlpha2Codes.contains(upper)) return upper;
  if (key.length == 3) {
    final fromAlpha3 = alpha3ToAlpha2[upper];
    if (fromAlpha3 != null) return fromAlpha3;
  }
  return _aliases[key] ?? cldrCountryNameCodes[key];
}
