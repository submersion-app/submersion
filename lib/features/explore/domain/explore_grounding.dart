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
///   als 30m"), so its clauses are not checked.
/// - A time is one of the prompt's English shapes. In every language, a
///   year the sentence does not contain is dropped. In English, so is a
///   period whose unit the sentence never names: "this year" on "dives with
///   Sarah", "this month" on "dives in March". Days, weeks and months count
///   as one unit, since "past month" may fairly become "last 30 days".
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
      if (!english || _isIn(c.text, said)) c,
  ];
  final time = parsed.time;
  final keepTime =
      time == null ||
      (_yearsAreIn(time.text, said) &&
          (!english || _unitIsIn(time.text, said)));
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

bool _isEnglish(String locale) =>
    locale.split(RegExp('[-_]')).first.toLowerCase() == 'en';

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
  return folded
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}

/// Whether [text] has words of its own and they all occur, in order, in
/// [said] (already [_comparable]).
bool _isIn(String text, String said) {
  final words = _comparable(text);
  return words.isNotEmpty && said.contains(words);
}

final _year = RegExp(r'\d{4}');

bool _yearsAreIn(String time, String said) =>
    _year.allMatches(_comparable(time)).every((m) => said.contains(m[0]!));

final _yearUnit = RegExp(r'\byears?\b');
final _shortUnit = RegExp(r'\b(?:days?|weeks?|months?)\b');

/// Whether [said] names the unit of the English period [time], if it has
/// one. Substrings on purpose: "today" names a day, "weekend" a week.
bool _unitIsIn(String time, String said) {
  final t = _comparable(time);
  if (_yearUnit.hasMatch(t) && !said.contains('year')) return false;
  if (_shortUnit.hasMatch(t) &&
      !['day', 'week', 'month', 'fortnight'].any(said.contains)) {
    return false;
  }
  return true;
}
