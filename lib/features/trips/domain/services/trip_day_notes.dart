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
}

/// Cuts [notes] into one passage per day of [days] (#4625).
///
/// A day heading is an ATX heading, outside any fenced code block, whose
/// text names a day ([dayNamedByHeading]). Its passage runs to the next
/// heading at the same level or a higher one, so deeper subheadings stay in
/// it. Text outside day headings belongs to no day.
TripDayNotes tripDayNotes(
  String notes,
  List<TripNoteDay> days,
  TripDayNotesVocabulary vocabulary,
) {
  if (notes.isEmpty || days.isEmpty) return TripDayNotes.empty;
  final lines = _lines(notes);
  final parts = <DateTime, List<String>>{};
  final ends = <DateTime, int>{};
  final headingEnds = <DateTime, int>{};

  // The open day passage: its day, its heading level and where its body
  // starts in the source.
  DateTime? openDay;
  var openLevel = 0;
  var openStart = 0;

  void close(int end) {
    final day = openDay;
    if (day == null) return;
    final body = notes.substring(openStart, end);
    final trimmed = _trimBlankLines(body);
    if (trimmed.isNotEmpty) {
      (parts[day] ??= []).add(trimmed);
      ends[day] = openStart + _lastContentEnd(body);
    }
    openDay = null;
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
    if (openDay != null && heading.level <= openLevel) close(line.start);
    if (openDay != null) continue;
    final day = dayNamedByHeading(heading.text, days, vocabulary);
    if (day == null) continue;
    openDay = day;
    openLevel = heading.level;
    openStart = line.end;
    headingEnds[day] = line.end;
  }
  close(notes.length);

  return TripDayNotes(
    passages: {
      for (final entry in parts.entries) entry.key: entry.value.join('\n\n'),
    },
    passageEnds: ends,
    headingLineEnds: headingEnds,
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
) {
  var text = headingText.trim().toLowerCase();
  if (text.endsWith('.') || text.endsWith(':')) {
    text = text.substring(0, text.length - 1).trimRight();
  }
  if (text.isEmpty) return null;

  final number = _labelNumber(text, vocabulary);
  if (number != null) {
    for (final day in days) {
      if (day.dayNumber == number) return day.date;
    }
    return null;
  }

  final iso = _isoDate.firstMatch(text);
  if (iso != null) {
    return _find(
      days,
      year: int.parse(iso[1]!),
      month: int.parse(iso[2]!),
      day: int.parse(iso[3]!),
    );
  }
  return _monthDay(text, days, vocabulary);
}

final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _digits = RegExp(r'^\d+$');
final RegExp _dayOfMonth = RegExp(r'^(\d{1,2})(st|nd|rd|th)?$');
final RegExp _year = RegExp(r'^\d{4}$');
final RegExp _separators = RegExp(r'[\s,]+');

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

DateTime? _monthDay(
  String text,
  List<TripNoteDay> days,
  TripDayNotesVocabulary vocabulary,
) {
  final tokens = [
    for (final token in text.split(_separators))
      if (token.isNotEmpty)
        token.endsWith('.') ? token.substring(0, token.length - 1) : token,
  ];
  var index = 0;
  final weekday = tokens.isNotEmpty ? vocabulary.weekdays[tokens[0]] : null;
  if (weekday != null) index++;
  if (tokens.length - index < 2) return null;

  int? month;
  int? day;
  final first = tokens[index];
  final second = tokens[index + 1];
  final firstMonth = vocabulary.months[first];
  if (firstMonth != null) {
    month = firstMonth;
    day = _dayNumber(second);
  } else {
    day = _dayNumber(first);
    month = vocabulary.months[second];
  }
  if (month == null || day == null) return null;
  index += 2;

  int? year;
  if (index < tokens.length && _year.hasMatch(tokens[index])) {
    year = int.parse(tokens[index]);
    index++;
  }
  if (index != tokens.length) return null;

  final date = _find(days, year: year, month: month, day: day);
  if (date == null) return null;
  if (weekday != null && date.weekday != weekday) return null;
  return date;
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
          text: source.substring(start),
          start: start,
          end: source.length,
        ));
      }
      break;
    }
    lines.add((
      text: source.substring(start, breakAt),
      start: start,
      end: breakAt + 1,
    ));
    start = breakAt + 1;
  }
  return lines;
}

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
