import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/date_symbols.dart';

import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/text/ascii_digits.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Words a diver types that stand for a value rather than for text (#3457):
// a year, a month, a setting, a gas. Each one joins the text match for that
// word, so a word never loses what it found before.
//
// Matching covers every language the app ships, not just the active one, so
// the compiler stays locale-free and a saved search finds the same dives on
// every device, as dive types do (issue #2884).

final List<AppLocalizations> _languages = [
  for (final locale in AppLocalizations.supportedLocales)
    lookupAppLocalizations(locale),
];

final _bareYear = RegExp(r'^\d{4}$');

/// A year from 1900 to 2200, the range the date grammar reads, in any number
/// script a keyboard here may type.
Iterable<String> diveYearTerms(String term) {
  final digits = asciiDigits(term.trim());
  if (!_bareYear.hasMatch(digits)) return const [];
  final year = int.parse(digits);
  return year < 1900 || year > 2200 ? const [] : [digits];
}

/// The calendar names of every app language. `dateTimeSymbolMap` builds every
/// locale on each call, so it is called once.
final List<DateSymbols> _calendars = () {
  final symbols = dateTimeSymbolMap();
  return [
    for (final locale in AppLocalizations.supportedLocales)
      symbols[locale.languageCode]!,
  ];
}();

Map<String, String> _calendarNames(
  List<List<String>> Function(DateSymbols symbols) lists,
  String Function(int index) value,
) {
  final names = <String, String>{};
  for (final symbols in _calendars) {
    for (final list in lists(symbols)) {
      for (final (index, name) in list.indexed) {
        names[name.toLowerCase()] = value(index);
      }
    }
  }
  return Map.unmodifiable(names);
}

/// Full month names only: `jan` is as likely a buddy, and counts as a month
/// only in a date phrase, beside a year. Values match `strftime('%m', ...)`.
final Map<String, String> _months = _calendarNames(
  (symbols) => [symbols.MONTHS, symbols.STANDALONEMONTHS],
  (index) => '${index + 1}'.padLeft(2, '0'),
);

/// Full weekday names only: `sun` and `sat` are words. Sunday first, which is
/// both the symbols' order and `strftime('%w', ...)`.
final Map<String, String> _weekdays = _calendarNames(
  (symbols) => [symbols.WEEKDAYS, symbols.STANDALONEWEEKDAYS],
  (index) => '$index',
);

Iterable<String> diveMonthTerms(String term) => [
  ?_months[term.trim().toLowerCase()],
];

Iterable<String> diveWeekdayTerms(String term) => [
  ?_weekdays[term.trim().toLowerCase()],
];

/// Every whole label of a setting, in every language, plus the [listed]
/// words, each mapped to the stored values it means. A single word from a
/// longer label does not count: `open` is not a dive mode, so `open water`
/// stays a search for a course.
Map<String, Set<String>> _settingWords(
  Map<String, String Function(AppLocalizations l10n)> labels,
  Map<String, Set<String>> listed,
) {
  final words = <String, Set<String>>{
    for (final MapEntry(:key, :value) in listed.entries) key: {...value},
  };
  for (final l10n in _languages) {
    for (final MapEntry(key: stored, value: label) in labels.entries) {
      (words[label(l10n).toLowerCase()] ??= {}).add(stored);
    }
  }
  return Map.unmodifiable(words);
}

final Map<String, Set<String>> _modes = _settingWords(
  {
    'oc': (l10n) => l10n.enum_diveMode_oc,
    'ccr': (l10n) => l10n.enum_diveMode_ccr,
    'scr': (l10n) => l10n.enum_diveMode_scr,
    'gauge': (l10n) => l10n.enum_diveMode_gauge,
  },
  const {
    'oc': {'oc'},
    'ccr': {'ccr'},
    'scr': {'scr'},
    'rebreather': {'ccr', 'scr'},
  },
);

/// `other` is left out: it describes nothing a diver would search for.
final Map<String, Set<String>> _entries = _settingWords(
  {
    'shore': (l10n) => l10n.enum_entryMethod_shore,
    'boat': (l10n) => l10n.enum_entryMethod_boat,
    'backRoll': (l10n) => l10n.enum_entryMethod_backRoll,
    'frontRoll': (l10n) => l10n.enum_entryMethod_frontRoll,
    'giantStride': (l10n) => l10n.enum_entryMethod_giantStride,
    'seatedEntry': (l10n) => l10n.enum_entryMethod_seatedEntry,
    'ladder': (l10n) => l10n.enum_entryMethod_ladder,
    'platform': (l10n) => l10n.enum_entryMethod_platform,
    'jetty': (l10n) => l10n.enum_entryMethod_jetty,
  },
  const {
    'jetty': {'jetty'},
    'dock': {'jetty'},
  },
);

final Map<String, Set<String>> _waters = _settingWords(
  {
    'salt': (l10n) => l10n.enum_waterType_salt,
    'fresh': (l10n) => l10n.enum_waterType_fresh,
    'brackish': (l10n) => l10n.enum_waterType_brackish,
  },
  const {
    'salt': {'salt'},
    'saltwater': {'salt'},
    'fresh': {'fresh'},
    'freshwater': {'fresh'},
  },
);

Iterable<String> diveModeTerms(String term) =>
    _modes[term.trim().toLowerCase()] ?? const {};

Iterable<String> diveEntryTerms(String term) =>
    _entries[term.trim().toLowerCase()] ?? const {};

Iterable<String> diveWaterTerms(String term) =>
    _waters[term.trim().toLowerCase()] ?? const {};

/// Both forms of the label, mapped to the stored value of `is_favorite`.
final Map<String, Set<String>> _favourites = _settingWords(
  {'1': (l10n) => l10n.enum_diveField_isFavorite},
  _settingWords(
    {'1': (l10n) => l10n.diveLog_filterChip_favorites},
    const {
      'favourite': {'1'},
      'favourites': {'1'},
    },
  ),
);

Iterable<String> diveFavouriteTerms(String term) =>
    _favourites[term.trim().toLowerCase()] ?? const {};

const _gasWords = {'air', 'nitrox', 'trimix'};

Iterable<String> diveGasTerms(String term) {
  final word = term.trim().toLowerCase();
  return _gasWords.contains(word) ? [word] : const [];
}

final _eanWord = RegExp(r'^ean(\d{2})$');

/// The oxygen percent an `eanNN` word names.
Iterable<String> diveEanTerms(String term) {
  final match = _eanWord.firstMatch(term.trim().toLowerCase());
  return match == null ? const [] : [match.group(1)!];
}

/// The multi-word labels of [_modes], [_entries] and [_waters], so the parser
/// keeps `salt water` together as one term.
final Set<String> diveLabelPhrases = Set.unmodifiable({
  for (final words in [_modes, _entries, _waters])
    for (final word in words.keys)
      if (word.contains(' ')) word,
});

bool diveLabelPhrase(List<String> words) =>
    diveLabelPhrases.contains(words.join(' '));

const kDivePlainWords = PlainWordReading(
  dateField: 'date',
  isPhrase: diveLabelPhrase,
);

/// The expansions for every word above. [entryMethodSql] and [waterTypeSql]
/// are the dive's effective values, the ones the matching fields read, as
/// templates over `{r}`.
///
/// Year, month and weekday compare the text `strftime` returns: a string bind
/// compares as a number only against a bare column (see
/// `kDiveNumberTextSearch`), so a cast here would match nothing. The gas `CASE`
/// mirrors `GasMix.isTrimix`, `isNitrox` and `isAir`.
List<TextSearchExpansion> diveWordExpansions({
  required String entryMethodSql,
  required String waterTypeSql,
}) => [
  const TextSearchExpansion(
    sql: "strftime('%Y', {r}.dive_date_time / 1000, 'unixepoch') IN ({values})",
    values: diveYearTerms,
  ),
  const TextSearchExpansion(
    sql: "strftime('%m', {r}.dive_date_time / 1000, 'unixepoch') IN ({values})",
    values: diveMonthTerms,
  ),
  const TextSearchExpansion(
    sql: "strftime('%w', {r}.dive_date_time / 1000, 'unixepoch') IN ({values})",
    values: diveWeekdayTerms,
  ),
  const TextSearchExpansion(
    sql: '{r}.dive_mode IN ({values})',
    values: diveModeTerms,
  ),
  TextSearchExpansion(
    sql: '$entryMethodSql IN ({values})',
    values: diveEntryTerms,
  ),
  const TextSearchExpansion(
    sql: '{r}.exit_method IN ({values})',
    values: diveEntryTerms,
  ),
  TextSearchExpansion(
    sql: '$waterTypeSql IN ({values})',
    values: diveWaterTerms,
  ),
  const TextSearchExpansion(
    sql: '{r}.is_favorite IN ({values})',
    values: diveFavouriteTerms,
  ),
  const TextSearchExpansion(
    sql:
        // A suit inflation bottle is not the dive's gas (issue #4243): an
        // air argon bottle must not make a trimix dive an air dive.
        'EXISTS (SELECT 1 FROM dive_tanks tgm WHERE tgm.dive_id = {r}.id '
        "AND (tgm.tank_role IS NULL OR tgm.tank_role <> 'suitInflation') "
        "AND CASE WHEN tgm.he_percent > 0 THEN 'trimix' "
        "WHEN tgm.o2_percent > 22 THEN 'nitrox' "
        "WHEN tgm.o2_percent >= 20 THEN 'air' END IN ({values}))",
    values: diveGasTerms,
  ),
  const TextSearchExpansion(
    sql:
        'EXISTS (SELECT 1 FROM dive_tanks tge WHERE tge.dive_id = {r}.id '
        "AND (tge.tank_role IS NULL OR tge.tank_role <> 'suitInflation') "
        "AND tge.he_percent = 0 AND printf('%d', ROUND(tge.o2_percent)) "
        'IN ({values}))',
    values: diveEanTerms,
  ),
];
