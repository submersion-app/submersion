import 'package:equatable/equatable.dart';

/// One day a heading in a trip's Notes can name: its date and the number
/// the day page shows for it.
class TripNoteDay extends Equatable {
  const TripNoteDay({required this.date, required this.dayNumber});

  /// Local date-only, as `TripStoryDay.date` is.
  final DateTime date;
  final int dayNumber;

  @override
  List<Object?> get props => [date, dayNumber];
}

/// The words a heading may use to name a day, in every language it is read
/// in. Everything is lowercase.
class TripDayNotesVocabulary extends Equatable {
  const TripDayNotesVocabulary({
    required this.dayLabels,
    required this.months,
    required this.weekdays,
  });

  /// The day label around its number, from each language's
  /// `trips_story_dayLabel` (`Day {number}` gives prefix `day`, suffix '').
  final List<({String prefix, String suffix})> dayLabels;

  /// Month names, full and abbreviated, with no trailing period, to 1..12.
  final Map<String, int> months;

  /// Weekday names, full and abbreviated, with no trailing period, to
  /// `DateTime.monday`..`DateTime.sunday`.
  final Map<String, int> weekdays;

  @override
  List<Object?> get props => [dayLabels, months, weekdays];
}

/// A trip's Notes cut into the passages that belong to its days.
class TripDayNotes {
  const TripDayNotes({
    required this.passages,
    required this.passageEnds,
    required this.headingLineEnds,
    this.dayHeadingLevel,
    this.unclosedFence,
  });

  static const empty = TripDayNotes(
    passages: {},
    passageEnds: {},
    headingLineEnds: {},
  );

  /// Day date to its passages, in note order, joined by a blank line.
  final Map<DateTime, String> passages;

  /// Day date to the source offset just after the last non-blank character
  /// of its last passage: where a caret goes to add to that day.
  final Map<DateTime, int> passageEnds;

  /// Day date to the source offset where its last heading line ends (the
  /// start of the next line, or the note's end). Present for every day a
  /// heading names, even one with nothing under it yet.
  final Map<DateTime, int> headingLineEnds;

  /// The shallowest level (1 to 6) of the note's day headings, for one or
  /// any day, or null when it has none: a heading added for another day
  /// takes this level, so it does not nest inside an earlier day.
  final int? dayHeadingLevel;

  /// The run that would close a fenced code block the note leaves open at
  /// its end (```` ``` ```` or `~~~~`), or null when every fence is closed.
  /// Anything appended after it would be code, not a heading.
  final String? unclosedFence;
}

/// Cuts [notes] into one passage per day of [days] (#4625).
///
/// A day heading is an ATX heading, outside any fenced code block, whose
/// text names a day ([dayNamedByHeading]). Its passage runs to the next
/// heading at the same level or a higher one, so deeper subheadings stay in
/// it. Text outside day headings belongs to no day.
///
/// A heading shaped like a day that is not one of [days] (`Day 12` on a
/// seven-day trip, or any day but the one asked for) holds its deeper
/// headings the same way and records nothing, so scanning for one day finds
/// what scanning for all of them does.
TripDayNotes tripDayNotes(
  String notes,
  List<TripNoteDay> days,
  TripDayNotesVocabulary vocabulary,
) {
  if (notes.isEmpty) return TripDayNotes.empty;
  final lines = _lines(notes);
  final parts = <DateTime, List<String>>{};
  final ends = <DateTime, int>{};
  final headingEnds = <DateTime, int>{};
  int? dayHeadingLevel;

  // The open day passage: its day (null for a day shape outside [days]),
  // its heading level and where its body starts in the source.
  var open = false;
  DateTime? openDay;
  var openLevel = 0;
  var openStart = 0;

  void close(int end) {
    final day = openDay;
    open = false;
    openDay = null;
    if (day == null) return;
    final body = notes.substring(openStart, end);
    final trimmed = _trimBlankLines(body);
    if (trimmed.isNotEmpty) {
      (parts[day] ??= []).add(trimmed);
      ends[day] = openStart + _lastContentEnd(body);
    }
  }

  _Fence? fence;
  for (final line in lines) {
    if (fence != null) {
      if (fence.closedBy(line.text)) fence = null;
      continue;
    }
    final opening = _Fence.openedBy(line.text);
    if (opening != null) {
      fence = opening;
      continue;
    }
    final heading = _Heading.parse(line.text);
    if (heading == null) continue;
    if (open && heading.level <= openLevel) close(line.start);
    if (open) continue;
    final named = _parseDayHeading(heading.text, vocabulary);
    if (named == null) continue;
    final day = named.resolve(days);
    if (dayHeadingLevel == null || heading.level < dayHeadingLevel) {
      dayHeadingLevel = heading.level;
    }
    open = true;
    openDay = day;
    openLevel = heading.level;
    openStart = line.end;
    if (day != null) headingEnds[day] = line.end;
  }
  close(notes.length);

  return TripDayNotes(
    passages: {
      for (final entry in parts.entries) entry.key: entry.value.join('\n\n'),
    },
    passageEnds: ends,
    headingLineEnds: headingEnds,
    dayHeadingLevel: dayHeadingLevel,
    unclosedFence: fence == null ? null : fence.char * fence.length,
  );
}

/// The day of [days] that [headingText] names, or null.
///
/// It names a day when the whole text, ignoring case, surrounding space and
/// one trailing period or colon, is a day label with that day's number, an
/// ISO date, or a month and day in either order (an optional weekday first,
/// an optional ordinal suffix, an optional year last). A date with no year
/// finds the day with that month and day. A weekday that is not the date's,
/// or anything else in the text, names nothing.
DateTime? dayNamedByHeading(
  String headingText,
  List<TripNoteDay> days,
  TripDayNotesVocabulary vocabulary,
) => _parseDayHeading(headingText, vocabulary)?.resolve(days);

/// The level (1 to 6) of [line] as an ATX heading, by the rule the scanner
/// uses, or null when it is not one. A trailing `\r` is ignored.
int? atxHeadingLevel(String line) =>
    _Heading.parse(_withoutCarriageReturn(line))?.level;

/// What a day heading says, before it is matched to a trip's days: a day
/// number, or a date whose year and weekday may be missing.
class _NamedDay {
  const _NamedDay.number(int this.dayNumber)
    : year = null,
      month = 0,
      day = 0,
      weekday = null;

  const _NamedDay.date({
    required this.year,
    required this.month,
    required this.day,
    this.weekday,
  }) : dayNumber = null;

  final int? dayNumber;
  final int? year;
  final int month;
  final int day;
  final int? weekday;

  DateTime? resolve(List<TripNoteDay> days) {
    final number = dayNumber;
    if (number != null) {
      for (final candidate in days) {
        if (candidate.dayNumber == number) return candidate.date;
      }
      return null;
    }
    final date = _find(days, year: year, month: month, day: day);
    if (date == null) return null;
    if (weekday != null && date.weekday != weekday) return null;
    return date;
  }
}

_NamedDay? _parseDayHeading(
  String headingText,
  TripDayNotesVocabulary vocabulary,
) {
  var text = headingText.trim().toLowerCase();
  if (text.endsWith('.') || text.endsWith(':')) {
    text = text.substring(0, text.length - 1).trimRight();
  }
  if (text.isEmpty) return null;

  final number = _labelNumber(text, vocabulary);
  if (number != null) return _NamedDay.number(number);

  final iso = _isoDate.firstMatch(text);
  if (iso != null) {
    return _NamedDay.date(
      year: int.parse(iso[1]!),
      month: int.parse(iso[2]!),
      day: int.parse(iso[3]!),
    );
  }

  // A leading weekday, possibly of several words (Hebrew `yom hamishi`).
  // A month can share its abbreviation with a weekday (`mar` is March and
  // Tuesday in Spanish, Italian and French), so the text is also read with
  // no weekday at all.
  for (final entry in vocabulary.weekdays.entries) {
    final rest = _afterWord(text, entry.key);
    if (rest == null) continue;
    final date = _monthDay(rest, vocabulary, weekday: entry.value);
    if (date != null) return date;
  }
  return _monthDay(text, vocabulary);
}

/// [text] after a leading [word] (and an abbreviation's period), when a
/// space or comma follows it; otherwise null.
String? _afterWord(String text, String word) {
  if (!text.startsWith(word)) return null;
  var rest = text.substring(word.length);
  if (rest.startsWith('.')) rest = rest.substring(1);
  if (rest.isEmpty || !_separatorStart.hasMatch(rest)) return null;
  return rest.replaceFirst(_separatorStart, '');
}

final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _digits = RegExp(r'^\d+$');
final RegExp _dayOfMonth = RegExp(r'^(\d{1,2})(st|nd|rd|th)?$');
final RegExp _year = RegExp(r'^\d{4}$');
final RegExp _separators = RegExp(r'[\s,]+');
final RegExp _separatorStart = RegExp(r'^[\s,]+');

int? _labelNumber(String text, TripDayNotesVocabulary vocabulary) {
  for (final label in vocabulary.dayLabels) {
    if (text.length <= label.prefix.length + label.suffix.length) continue;
    if (!text.startsWith(label.prefix) || !text.endsWith(label.suffix)) {
      continue;
    }
    final middle = text
        .substring(label.prefix.length, text.length - label.suffix.length)
        .trim();
    if (_digits.hasMatch(middle)) return int.parse(middle);
  }
  return null;
}

/// A month and day in either order, then an optional year, and nothing else.
_NamedDay? _monthDay(
  String text,
  TripDayNotesVocabulary vocabulary, {
  int? weekday,
}) {
  final tokens = [
    for (final token in text.split(_separators))
      if (token.isNotEmpty)
        token.endsWith('.') ? token.substring(0, token.length - 1) : token,
  ];
  if (tokens.length < 2 || tokens.length > 3) return null;

  final [first, second, ...rest] = tokens;
  final firstMonth = vocabulary.months[first];
  final month = firstMonth ?? vocabulary.months[second];
  final day = _dayNumber(firstMonth == null ? first : second);
  if (month == null || day == null) return null;

  int? year;
  if (rest.isNotEmpty) {
    if (!_year.hasMatch(rest.single)) return null;
    year = int.parse(rest.single);
  }
  return _NamedDay.date(year: year, month: month, day: day, weekday: weekday);
}

int? _dayNumber(String token) {
  final match = _dayOfMonth.firstMatch(token);
  return match == null ? null : int.parse(match[1]!);
}

DateTime? _find(
  List<TripNoteDay> days, {
  required int? year,
  required int month,
  required int day,
}) {
  for (final candidate in days) {
    final date = candidate.date;
    if (date.month == month &&
        date.day == day &&
        (year == null || date.year == year)) {
      return date;
    }
  }
  return null;
}

/// A source line: its text without the line break, where it starts, and
/// where the next line starts.
typedef _Line = ({String text, int start, int end});

List<_Line> _lines(String source) {
  final lines = <_Line>[];
  var start = 0;
  while (start <= source.length) {
    final breakAt = source.indexOf('\n', start);
    if (breakAt < 0) {
      if (start < source.length) {
        lines.add((
          text: _withoutCarriageReturn(source.substring(start)),
          start: start,
          end: source.length,
        ));
      }
      break;
    }
    lines.add((
      text: _withoutCarriageReturn(source.substring(start, breakAt)),
      start: start,
      end: breakAt + 1,
    ));
    start = breakAt + 1;
  }
  return lines;
}

/// A line's text without the `\r` a Windows line ending leaves on it.
String _withoutCarriageReturn(String line) =>
    line.endsWith('\r') ? line.substring(0, line.length - 1) : line;

/// An open fenced code block: the character and length of its opening run.
class _Fence {
  const _Fence(this.char, this.length);

  final String char;
  final int length;

  static final RegExp _opening = RegExp(r'^ {0,3}(`{3,}|~{3,})');

  static _Fence? openedBy(String line) {
    final match = _opening.firstMatch(line);
    if (match == null) return null;
    final run = match[1]!;
    // A backtick run with another backtick after it on the line is a code
    // span (```npm i```), not a fence, as in CommonMark.
    if (run[0] == '`' && line.substring(match.end).contains('`')) return null;
    return _Fence(run[0], run.length);
  }

  bool closedBy(String line) {
    final match = _opening.firstMatch(line);
    if (match == null) return false;
    final run = match[1]!;
    return run[0] == char &&
        run.length >= length &&
        line.substring(match.end).trim().isEmpty;
  }
}

/// An ATX heading: its level and its text without the marker or a closing
/// run of hashes.
class _Heading {
  const _Heading(this.level, this.text);

  final int level;
  final String text;

  static final RegExp _atx = RegExp(r'^ {0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t]*$');
  static final RegExp _closing = RegExp(r'(?:^|[ \t]+)#+$');

  static _Heading? parse(String line) {
    final match = _atx.firstMatch(line);
    if (match == null) return null;
    final text = (match[2] ?? '').replaceFirst(_closing, '').trim();
    return _Heading(match[1]!.length, text);
  }
}

String _trimBlankLines(String body) {
  final lines = body.split('\n');
  var first = 0;
  var last = lines.length - 1;
  while (first <= last && lines[first].trim().isEmpty) {
    first++;
  }
  while (last >= first && lines[last].trim().isEmpty) {
    last--;
  }
  if (first > last) return '';
  return lines.sublist(first, last + 1).join('\n').trimRight();
}

/// The offset in [body] just after its last non-blank character.
int _lastContentEnd(String body) {
  var end = body.length;
  while (end > 0 && body[end - 1].trim().isEmpty) {
    end--;
  }
  return end;
}
