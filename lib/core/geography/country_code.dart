import 'package:submersion/core/geography/country_names.generated.dart';
import 'package:submersion/core/text/text_sort.dart';

/// Names divers use that CLDR does not list, each with one unambiguous
/// country (issue #4426), written as they appear and folded into [_aliases].
/// CLDR's own names in every place-name language and each country's official
/// languages live in the generated table.
/// "USA" and "Czech Republic" need no entry: the alpha-3 code and CLDR's
/// own variant name already find them.
const Map<String, String> _aliasNames = {
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
  // OpenStreetMap's own country names that CLDR words differently, as the
  // bundled dive sites and geocoded sites carry them (issue #4520).
  'ประเทศไทย': 'TH',
  'Ελλάς': 'GR',
  'Κύπρος - Kıbrıs': 'CY',
  'Shqipëria': 'AL',
  'السعودية': 'SA',
  'عمان': 'OM',
  'Algérie ⵍⵣⵣⴰⵢⴻⵔ الجزائر': 'DZ',
  'Djibouti جيبوتي': 'DJ',
  'ព្រះរាជាណាចក្រ​កម្ពុជា': 'KH',
  '臺灣': 'TW',
  'Belau': 'PW',
  'Ṃajeḷ': 'MH',
  'Sesel': 'SC',
};

/// [_aliasNames] keyed by [countryLookupKey].
final Map<String, String> _aliases = {
  for (final MapEntry(:key, :value) in _aliasNames.entries)
    countryLookupKey(key): value,
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

/// Folded length below which a search query is read as a whole code or name
/// only: two letters start dozens of country names.
const int _minNamePrefixLength = 3;

/// The codes of the countries a search [query] names (issue #4520), so a
/// search finds sites whose country is stored in another language
/// ("ประเทศไทย" for "Thailand" or "Thaïlande").
///
/// Holds the country [countryCodeFor] reads the whole query as, and, from
/// three folded characters on, every country with a name in any known
/// language (or an alias) that starts with it, so "thai" finds Thailand
/// while it is still being typed. Only the start of a name counts: "land"
/// would otherwise list Thailand and Switzerland. Empty when the query names
/// no country.
Set<String> countryCodesMatching(String query) {
  final key = countryLookupKey(query);
  if (key.isEmpty) return const {};
  final codes = <String>{?countryCodeFor(query)};
  if (key.length < _minNamePrefixLength) return codes;
  for (final names in [cldrCountryNameCodes, _aliases]) {
    for (final MapEntry(key: name, value: code) in names.entries) {
      if (name.startsWith(key)) codes.add(code);
    }
  }
  return codes;
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
