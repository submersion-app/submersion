import 'source_mask.dart';

/// Names that mark a `DateTime` as a dive time: a downloaded or imported
/// dive's `startTime`, the dive entity's `dateTime`, `entryTime` and
/// `exitTime`, and the stored `diveDateTime`.
final RegExp diveTimeName = RegExp(
  r'start_?time|date_?time|entry_?time|exit_?time',
  caseSensitive: false,
);

final RegExp _toLocal = RegExp(r'\??\.toLocal\(\)');
final RegExp _chainUnit = RegExp(r'[A-Za-z0-9_$.!?]');

/// Every `.toLocal()` call in [source] whose receiver names a dive time, as
/// `line: receiver.toLocal()`.
///
/// Dive times are the dive's wall clock flagged UTC, so `DateFormat` prints
/// them as they are, and converting one to the device's zone shifts the
/// shown time, and near midnight the date, by the device's UTC offset (issue
/// #2892). Calls are found in code only, so a comment or a string that spells
/// one out does not count.
///
/// The match is by name, so a dive time held in a variable with an unrelated
/// name (`start`) is not seen, and a real instant that happens to carry one
/// of these names (HealthKit's `startTime`) is; the caller allowlists those.
List<String> findDiveTimeToLocalCalls(String source) {
  final masked = MaskedSource(source);
  final code = masked.code;
  final offenders = <String>[];
  for (final match in _toLocal.allMatches(code)) {
    final begin = _receiverStart(code, match.start);
    final receiver = code.substring(begin, match.start);
    if (!diveTimeName.hasMatch(receiver)) continue;
    offenders.add(
      '${masked.lineOf(begin)}: ${masked.text.substring(begin, match.end)}',
    );
  }
  return offenders;
}

/// The offset where the receiver ending just before [end] starts: a chain of
/// identifiers, `.`, `!` and `?`, with any bracketed group (a call's
/// arguments, an index, a parenthesised expression) taken whole.
int _receiverStart(String code, int end) {
  var i = end - 1;
  while (i >= 0) {
    final unit = code[i];
    if (unit == ')' || unit == ']') {
      i = _openingBracket(code, i) - 1;
    } else if (_chainUnit.hasMatch(unit)) {
      i--;
    } else {
      break;
    }
  }
  return i + 1;
}

/// The offset of the bracket that opens the one closing at [close] in
/// [code], or 0 when it never opens.
int _openingBracket(String code, int close) {
  var depth = 0;
  for (var i = close; i >= 0; i--) {
    final unit = code[i];
    if (unit == ')' || unit == ']') {
      depth++;
    } else if (unit == '(' || unit == '[') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return 0;
}
