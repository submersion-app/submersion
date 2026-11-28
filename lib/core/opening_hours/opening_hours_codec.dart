import 'dart:convert';
import 'dart:developer' as developer;

import 'package:submersion/core/opening_hours/opening_hours.dart';

/// Stored form of [OpeningHours] (issue #5073): one JSON object in a text
/// column, versioned so later fields need no schema rung.
///
/// ```json
/// {"v": 1, "alwaysOpen": false, "note": "...",
///  "schedules": [{"name": "Summer",
///                 "season": {"start": "04-01", "end": "10-31"},
///                 "days": {"sat": [[480, 720], [780, 1020]], "sun": "24h"}}]}
/// ```
///
/// A missing day is closed. Decoding never throws: the value can arrive
/// from another device, a CSV or UDDF file or an agent, so a bad part is
/// dropped (and logged) and a value that is not an object reads as null.
///
/// A later version only adds to this one, so a newer value is read by the
/// fields this version knows. Every site save writes the hours again, so
/// until they are edited such a value is written back as it was stored,
/// keeping what this version cannot read.

const int _version = 1;
const String _open24h = '24h';

const List<String> _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

String _dayKey(int weekday) => _dayKeys[weekday - DateTime.monday];

/// The stored text of hours decoded from a newer version, by the decoded
/// value; an edit makes a new value, which this version then writes.
final Expando<String> _newerStoredText = Expando('newerOpeningHoursText');

/// The stored text for [hours]; null when there is nothing to store.
String? encodeOpeningHours(OpeningHours? hours) {
  if (hours == null || hours.isEmpty) return null;
  final kept = _newerStoredText[hours];
  if (kept != null) return kept;
  final note = hours.note?.trim();
  return jsonEncode({
    'v': _version,
    'alwaysOpen': hours.alwaysOpen,
    if (note != null && note.isNotEmpty) 'note': note,
    'schedules': [for (final s in hours.schedules) _encodeSchedule(s)],
  });
}

Map<String, Object?> _encodeSchedule(OpeningSchedule schedule) {
  final name = schedule.name?.trim();
  final season = schedule.season;
  return {
    if (name != null && name.isNotEmpty) 'name': name,
    if (season != null)
      'season': {
        'start': _encodeMonthDay(season.start),
        'end': _encodeMonthDay(season.end),
      },
    'days': {
      for (var d = DateTime.monday; d <= DateTime.sunday; d++)
        if (!schedule.dayHours(d).isClosed)
          _dayKey(d): _encodeDay(schedule.dayHours(d)),
    },
  };
}

Object _encodeDay(DayHours day) => switch (day.kind) {
  DayHoursKind.open24h => _open24h,
  _ => [
    for (final r in day.ranges) [r.opensAt, r.closesAt],
  ],
};

String _encodeMonthDay(MonthDay d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The hours stored as [text]; null when there are none or they cannot be
/// read.
OpeningHours? decodeOpeningHours(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    _drop('stored value is not JSON: ${e.message}');
    return null;
  }
  if (json is! Map) {
    _drop('stored value is not an object');
    return null;
  }
  final rawNote = json['note'];
  final note = rawNote is String && rawNote.trim().isNotEmpty
      ? rawNote.trim()
      : null;
  final rawSchedules = json['schedules'];
  final schedules = <OpeningSchedule>[
    if (rawSchedules is List)
      for (final raw in rawSchedules)
        if (raw is Map) _decodeSchedule(raw) else ?_dropNull('a schedule'),
  ];
  final hours = OpeningHours(
    alwaysOpen: json['alwaysOpen'] == true,
    schedules: List.unmodifiable(schedules),
    note: note,
  );
  if (hours.isEmpty) return null;
  final version = json['v'];
  if (version is num && version > _version) {
    developer.log(
      'Read version $version by its version $_version fields; kept as '
      'stored until edited',
      name: 'OpeningHoursCodec',
    );
    _newerStoredText[hours] = text;
  }
  return hours;
}

OpeningSchedule _decodeSchedule(Map raw) {
  final name = raw['name'];
  final days = <int, DayHours>{};
  final rawDays = raw['days'];
  if (rawDays is Map) {
    for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
      final value = rawDays[_dayKey(d)];
      if (value == null) continue;
      final day = _decodeDay(value);
      if (!day.isClosed) days[d] = day;
    }
  }
  return OpeningSchedule(
    name: name is String && name.trim().isNotEmpty ? name.trim() : null,
    season: _decodeSeason(raw['season']),
    days: Map.unmodifiable(days),
  );
}

DayHours _decodeDay(Object value) {
  if (value == _open24h) return const DayHours.open24h();
  if (value is! List) {
    _drop('a day that is neither "24h" nor a list');
    return const DayHours.closed();
  }
  // A whole number written as a decimal (540.0, from an agent or a
  // hand-edited cell) is still a minute; a fraction is not.
  int? minute(Object? v) => switch (v) {
    final int i => i,
    final double d when d == d.roundToDouble() => d.toInt(),
    _ => null,
  };
  final ranges = <TimeRange>[];
  for (final r in value) {
    final opens = r is List && r.length == 2 ? minute(r[0]) : null;
    final closes = r is List && r.length == 2 ? minute(r[1]) : null;
    if (opens != null && closes != null) {
      final range = TimeRange(opens, closes);
      if (range.isValid) {
        ranges.add(range);
        continue;
      }
    }
    _drop('a time range $r');
  }
  return DayHours.ranges(ranges);
}

YearlyDateRange? _decodeSeason(Object? raw) {
  if (raw == null) return null;
  if (raw is Map) {
    final start = _decodeMonthDay(raw['start']);
    final end = _decodeMonthDay(raw['end']);
    if (start != null && end != null) {
      return YearlyDateRange(start: start, end: end);
    }
  }
  _drop('a season $raw; the schedule applies all year');
  return null;
}

MonthDay? _decodeMonthDay(Object? raw) {
  if (raw is! String) return null;
  final match = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(raw);
  if (match == null) return null;
  final day = MonthDay(int.parse(match[1]!), int.parse(match[2]!));
  return day.isValid ? day : null;
}

void _drop(String what) =>
    developer.log('Dropped $what', name: 'OpeningHoursCodec');

OpeningSchedule? _dropNull(String what) {
  _drop(what);
  return null;
}
