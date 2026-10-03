import 'source_mask.dart';

/// Names that mark an epoch-milliseconds value as a stored dive time:
/// `dives.dive_date_time` and `dives.entry_time`, the MIN / MAX aliases the
/// repositories give them (`first_dive`, `last_seen`, `last_dived`, ...), and
/// the Dart names those values travel under (`diveDateTime`, `entryTimeMs`,
/// `firstSeenMs`, ...).
final RegExp diveDateName = RegExp(
  r'dive_?date_?time|entry_?time|first_?dive|last_?dive|first_?seen|last_?seen',
  caseSensitive: false,
);

const _call = 'DateTime.fromMillisecondsSinceEpoch(';
final RegExp _utcFlag = RegExp(r'isUtc\s*:\s*true');
final RegExp _whitespace = RegExp(r'\s+');

/// Every `DateTime.fromMillisecondsSinceEpoch(...)` call in [source] that
/// decodes a stored dive time without `isUtc: true`, as `line: call`.
///
/// Dive times are stored as the dive's wall clock flagged UTC, so a plain
/// decode reads them as local time and shifts every calendar field by the
/// device's UTC offset (issues #2805, #2808, #2810). Calls are found in code
/// only, so a comment or a string that spells one out does not count, but the
/// call's own text is matched with its strings kept, because the column name
/// usually sits in one (`row.read<int>('dive_date_time')`).
///
/// The match is by name, so a dive time held in a variable with an unrelated
/// name (`ms`) is not seen. That is why decoding through
/// `wallClockUtcFromMillis` is the rule, and this scan only its ratchet.
List<String> findLocalDiveDateDecodes(String source) {
  final masked = MaskedSource(source);
  final code = masked.code;
  final offenders = <String>[];
  var from = 0;
  while (true) {
    final start = code.indexOf(_call, from);
    if (start < 0) break;
    final end = _closingParen(code, start + _call.length - 1);
    from = end + 1;
    final call = masked.text.substring(start, end + 1);
    if (_utcFlag.hasMatch(call) || !diveDateName.hasMatch(call)) continue;
    offenders.add(
      '${masked.lineOf(start)}: ${call.replaceAll(_whitespace, ' ')}',
    );
  }
  return offenders;
}

/// The offset of the parenthesis that closes the one at [open] in [code], or
/// the end of [code] when it never closes.
int _closingParen(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final unit = code[i];
    if (unit == '(') {
      depth++;
    } else if (unit == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return code.length - 1;
}
