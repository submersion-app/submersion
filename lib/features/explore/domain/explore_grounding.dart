import 'package:submersion/core/query/syntax/date_grammar.dart';
import 'package:submersion/core/text/fuzzy_match.dart' as fuzzy;
import 'package:submersion/features/explore/domain/query_model.dart';

/// [parsed] without what the model read into [sentence] but the diver never
/// wrote (#2838).
///
/// A small on-device model copies the prompt's examples into sentences that
/// never asked for them: a "cold-water" filter on "deep dives in Bonaire", a
/// "since 2022" period on "dives with Sarah".
///
/// - A clause's text is the words it came from, so in English a clause whose
///   words are not in the sentence is dropped. In any other [locale] the
///   model often quotes the clause in English ("deeper than 30" for "tiefer
///   als 30m"), so its clauses are only checked for a year: a clause whose
///   value names a year the sentence lacks ("not dived since 2022") is
///   dropped in every language.
/// - A time is one of the prompt's English shapes. In every language, a
///   year the sentence does not contain is dropped. In English, so is a
///   period whose unit the sentence never names: "this year" on "dives with
///   Sarah", "this month" on "dives in March". Days, weeks and months count
///   as one unit, since "past month" may fairly become "last 30 days". So is
///   a month the sentence never names, in full or abbreviated: "May 2023" on
///   "dives in March 2023".
///
/// Returns [parsed] itself when nothing is dropped.
ParsedQuery groundedIn(
  ParsedQuery parsed,
  String sentence, {
  required String locale,
}) {
  final said = _comparable(sentence);
  final english = _isEnglish(locale);
  final clauses = [
    for (final c in parsed.clauses)
      if (_yearsAreIn(_comparable(_valueText(c.value)), said) &&
          (!english || _isIn(c.text, said)))
        c,
  ];
  final time = parsed.time;
  final t = time == null ? null : _comparable(time.text);
  final keepTime =
      t == null || (_yearsAreIn(t, said) && (!english || _unitIsIn(t, said)));
  if (clauses.length == parsed.clauses.length && keepTime) return parsed;
  return ParsedQuery(
    schemaVersion: parsed.schemaVersion,
    subject: parsed.subject,
    clauses: clauses,
    mentions: parsed.mentions,
    time: keepTime ? time : null,
    unplaced: parsed.unplaced,
  );
}

final _tagSeparator = RegExp('[-_]');

bool _isEnglish(String locale) =>
    locale.split(_tagSeparator).first.toLowerCase() == 'en';

final _notLettersOrDigits = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// [text] with case, accents and full-width digits folded, and every run of
/// anything but letters and digits made one space, so "Cold-Water" and
/// "cold water" compare equal.
String _comparable(String text) {
  final folded = String.fromCharCodes(
    fuzzy
        .normalize(text)
        .runes
        .map((r) => r >= 0xFF10 && r <= 0xFF19 ? r - 0xFF10 + 0x30 : r),
  );
  return folded.replaceAll(_notLettersOrDigits, ' ').trim();
}

/// Whether [text] has words of its own and they all occur, in order, in
/// [said] (already [_comparable]).
bool _isIn(String text, String said) {
  final words = _comparable(text);
  return words.isNotEmpty && said.contains(words);
}

/// The words of a clause value: a time field's value is a period such as
/// "2022", and an `in` list may hold several.
String _valueText(Object value) => switch (value) {
  final String s => s,
  final List<Object?> l => l.whereType<String>().join(' '),
  _ => '',
};

final _year = RegExp(r'\d{4}');

/// Whether every year in [text] (already [_comparable]) is in [said].
bool _yearsAreIn(String text, String said) =>
    _year.allMatches(text).every((m) => said.contains(m[0]!));

final _yearUnit = RegExp(r'\byears?\b');
final _shortUnit = RegExp(r'\b(?:days?|weeks?|months?)\b');

/// The words that name a day, week or month. Whole words: a weekday
/// ("Sunday") or "holiday" ends in "day" but names no span.
final _shortUnitSaid = RegExp(
  r'\b(?:days?|weeks?|weekends?|fortnights?|months?|today|tonight|yesterday)\b',
);

/// The months [words] (already [_comparable]) name as words.
Set<int> _monthsNamedIn(String words) => {
  for (final w in words.split(' ')) ?monthOfWord(w),
};

/// A year and month written as digits, "2023-05" or "2023-05-14", once
/// [_comparable] has made the dashes spaces.
final _digitMonth = RegExp(r'\b\d{4} (0[1-9]|1[0-2])\b');

/// Whether [said] names the unit and every month of the English period
/// [time] (both already [_comparable]).
bool _unitIsIn(String time, String said) {
  if (_yearUnit.hasMatch(time) && !_yearUnit.hasMatch(said)) return false;
  if (_shortUnit.hasMatch(time) && !_shortUnitSaid.hasMatch(said)) {
    return false;
  }
  final months = _monthsNamedIn(time);
  if (months.isEmpty) return true;
  return {
    ..._monthsNamedIn(said),
    for (final m in _digitMonth.allMatches(said)) int.parse(m[1]!),
  }.containsAll(months);
}
