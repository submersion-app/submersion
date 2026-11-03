/// Month names in the app language, for the date grammar (#3457). A date
/// phrase becomes fixed dates when it is parsed, so reading it in one language
/// changes nothing for a saved search on a device set to another.
library;

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/date_symbols.dart';

import 'package:submersion/core/text/fuzzy_match.dart';

/// Hebrew attaches "in" to the month: `14 באוקטובר 2018`.
const Map<String, String> _monthPrefixes = {'he': 'ב'};

/// Built once per language, since `dateTimeSymbolMap` builds every locale on
/// each call and keeping its result would keep them all.
final Map<String, Map<String, int>> _namesByLanguage = {};

Map<String, int> _readNames(String language) {
  final DateSymbols? symbols = dateTimeSymbolMap()[language];
  if (symbols == null) return const {};
  final prefix = _monthPrefixes[language] ?? '';
  final names = <String, int>{};
  for (final list in [
    symbols.MONTHS,
    symbols.STANDALONEMONTHS,
    symbols.SHORTMONTHS,
    symbols.STANDALONESHORTMONTHS,
  ]) {
    for (final (index, name) in list.indexed) {
      final word = normalize(name).replaceAll('.', '');
      names[word] = index + 1;
      names['$prefix$word'] = index + 1;
    }
  }
  return names;
}

/// The month (1 to 12) [word] names in [language], in full or abbreviated,
/// with or without its accents, or null.
int? monthInLanguage(String word, String language) =>
    (_namesByLanguage[language] ??= _readNames(language))[normalize(word)];
