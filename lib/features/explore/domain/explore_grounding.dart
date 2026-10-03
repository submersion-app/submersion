import 'package:submersion/core/text/fuzzy_match.dart' as fuzzy;
import 'package:submersion/features/explore/domain/query_model.dart';

/// [parsed] without what the model read into [sentence] but the diver never
/// wrote (#2838).
///
/// A small on-device model copies the prompt's examples into sentences that
/// never asked for them: a "cold-water" filter on "deep dives in Bonaire", a
/// "since 2022" period on "dives with Sarah". Both checks hold in any
/// language, because they compare the diver's own characters:
///
/// - A clause's text is the words it came from, so a clause whose words are
///   not in the sentence is dropped.
/// - A time is one of the prompt's English shapes, so only its year can be
///   checked: a year the sentence does not contain is dropped. A period
///   without one ("last year" from "letztes Jahr") is left to the prompt.
///
/// Returns [parsed] itself when nothing is dropped.
ParsedQuery groundedIn(ParsedQuery parsed, String sentence) {
  final said = _comparable(sentence);
  final clauses = [
    for (final c in parsed.clauses)
      if (_isIn(c.text, said)) c,
  ];
  final time = parsed.time;
  final keepTime = time == null || _yearsAreIn(time.text, said);
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
