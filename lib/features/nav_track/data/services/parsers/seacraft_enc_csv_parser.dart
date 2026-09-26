import 'dart:typed_data';

import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_parser.dart';

/// Shared RFC-4180 reader (quotes, embedded newlines, CRLF normalisation).
///
/// Splitting on bare commas would misalign any quoted field containing
/// one, the same reasoning `csv_track_parser.dart` gives for the GPS
/// logger's CSV import.
const _reader = CsvParser();

const _bom = '\u{FEFF}';

/// Index of the header named [name] (case-insensitive, trimmed, BOM
/// stripped from the first header), or -1 when it is not present.
int _headerIndex(List<String> headers, String name) {
  for (var i = 0; i < headers.length; i++) {
    var h = headers[i].trim().toLowerCase();
    if (i == 0 && h.startsWith(_bom)) {
      h = h.substring(_bom.length);
    }
    if (h == name) return i;
  }
  return -1;
}

/// Parses a Seacraft ENC / ENC3 / ENC3-PRO navigation console CSV export.
///
/// The recording carries no coordinates of its own: [NavTrackPoint.north]
/// and [NavTrackPoint.east] are metres relative to the log's own start
/// (a north-east-down frame, verified against the `Course` column -- see
/// the design spec `2026-09-10-underwater-nav-track-design.md`). Segmenting
/// a surface GPS re-calibration jump out of the route is
/// `NavTrackSegmenter`'s job, not this parser's: every row the file
/// contains comes back as a point, in file order.
///
/// Times are the console's own wall clock with no zone, combined with
/// `DateTime.utc` so the value is that wall clock reinterpreted as UTC on
/// every machine, matching the wall-clock-as-UTC convention
/// `dives.entryTime` uses. Parsing through `DateTime.parse` instead would
/// fold in the importing machine's own timezone offset.
ParsedNavTrack parseSeacraftEncCsv(Uint8List bytes) {
  final ParsedCsv parsed;
  try {
    parsed = _reader.parse(bytes);
  } on CsvParseException catch (e) {
    throw NavTrackParseException(e.message);
  }

  final headers = parsed.headers;
  final dateIdx = _headerIndex(headers, 'date');
  final timeIdx = _headerIndex(headers, 'time');
  final xIdx = _headerIndex(headers, 'pos3dx');
  final yIdx = _headerIndex(headers, 'pos3dy');
  final zIdx = _headerIndex(headers, 'pos3dz');
  if (dateIdx < 0 || timeIdx < 0 || xIdx < 0 || yIdx < 0 || zIdx < 0) {
    throw const NavTrackParseException(
      'missing one of the required columns: '
      'date, time, Pos3Dx, Pos3Dy, Pos3Dz',
    );
  }

  // Optional channels: looked up by name, so a firmware that appends or
  // reorders columns still imports.
  final courseIdx = _headerIndex(headers, 'course');
  final pitchIdx = _headerIndex(headers, 'pitch');
  final rollIdx = _headerIndex(headers, 'roll');
  final distanceIdx = _headerIndex(headers, 'distance');
  final speedIdx = _headerIndex(headers, 'speed');
  final tempIdx = _headerIndex(headers, 'temp');
  final battIdx = _headerIndex(headers, 'battv');

  final points = <NavTrackPoint>[];
  int? lastTimestamp;

  for (var i = 0; i < parsed.rows.length; i++) {
    final row = parsed.rows[i];
    final rowNumber = i + 2; // the header occupies row 1

    String? cell(int index) {
      if (index < 0 || index >= row.length) return null;
      final value = row[index].trim();
      return value.isEmpty ? null : value;
    }

    // `double.tryParse` happily returns `double.nan` for "NaN" and
    // `double.infinity`/`double.negativeInfinity` for "Infinity"/"-Infinity"
    // rather than null, so a required column's null check alone lets a
    // malformed CSV persist a non-finite coordinate or depth that later
    // turns route statistics, segmentation, correction and map/3D geometry
    // into NaN or otherwise invalid values. An optional channel degrades to
    // null instead, consistent with how an out-of-range Course or a
    // negative BattV already becomes null rather than failing the import.
    double? optionalDouble(int index) {
      final text = cell(index);
      if (text == null) return null;
      final value = double.tryParse(text);
      if (value == null || !value.isFinite) return null;
      return value;
    }

    double requiredDouble(int index, String name) {
      final text = cell(index);
      if (text == null) {
        throw NavTrackParseException(
          'Row $rowNumber: missing $name',
          reason: NavTrackParseReason.badData,
        );
      }
      final value = double.tryParse(text);
      if (value == null || !value.isFinite) {
        throw NavTrackParseException(
          'Row $rowNumber: unparseable $name "$text"',
          reason: NavTrackParseReason.badData,
        );
      }
      return value;
    }

    final dateText = cell(dateIdx);
    final timeText = cell(timeIdx);
    if (dateText == null || timeText == null) {
      throw NavTrackParseException(
        'Row $rowNumber: missing date or time',
        reason: NavTrackParseReason.badData,
      );
    }
    final timestamp = _parseTimestamp(dateText, timeText, rowNumber);
    if (lastTimestamp != null && timestamp < lastTimestamp) {
      throw NavTrackParseException(
        'Row $rowNumber: timestamp goes backwards',
        reason: NavTrackParseReason.badData,
      );
    }
    lastTimestamp = timestamp;

    final north = requiredDouble(xIdx, 'Pos3Dx');
    final east = requiredDouble(yIdx, 'Pos3Dy');
    var depth = requiredDouble(zIdx, 'Pos3Dz');
    if (depth < -1) {
      throw NavTrackParseException(
        'Row $rowNumber: depth ${depth}m is implausibly above the surface',
        reason: NavTrackParseReason.badData,
      );
    }
    if (depth < 0) depth = 0;

    var course = optionalDouble(courseIdx);
    if (course != null && (course < 0 || course > 360)) {
      course = null;
    }

    final speedPerMinute = optionalDouble(speedIdx);

    var batteryVolts = optionalDouble(battIdx);
    if (batteryVolts != null && batteryVolts < 0) {
      batteryVolts = null;
    }

    points.add(
      NavTrackPoint(
        timestamp: timestamp,
        north: north,
        east: east,
        depth: depth,
        course: course,
        pitch: optionalDouble(pitchIdx),
        roll: optionalDouble(rollIdx),
        distance: optionalDouble(distanceIdx),
        // The source logs m/min; every other speed field in the app is SI.
        speed: speedPerMinute == null ? null : speedPerMinute / 60.0,
        temperature: optionalDouble(tempIdx),
        batteryVolts: batteryVolts,
      ),
    );
  }

  if (points.length < 2) {
    throw const NavTrackParseException(
      'file has fewer than two samples',
      reason: NavTrackParseReason.tooShort,
    );
  }
  validateNavTrackPointCount(points.length);

  return ParsedNavTrack(points: points);
}

/// Combines the console's `d.M.yyyy` date and `H:mm:ss` time into a
/// wall-clock-as-UTC epoch in seconds.
int _parseTimestamp(String dateText, String timeText, int rowNumber) {
  final dateParts = dateText.split('.');
  final timeParts = timeText.split(':');
  if (dateParts.length != 3 || timeParts.length != 3) {
    throw NavTrackParseException(
      'Row $rowNumber: unparseable date/time "$dateText $timeText"',
      reason: NavTrackParseReason.badData,
    );
  }
  final day = int.tryParse(dateParts[0]);
  final month = int.tryParse(dateParts[1]);
  final year = int.tryParse(dateParts[2]);
  final hour = int.tryParse(timeParts[0]);
  final minute = int.tryParse(timeParts[1]);
  final second = int.tryParse(timeParts[2]);
  if (day == null ||
      month == null ||
      year == null ||
      hour == null ||
      minute == null ||
      second == null) {
    throw NavTrackParseException(
      'Row $rowNumber: unparseable date/time "$dateText $timeText"',
      reason: NavTrackParseReason.badData,
    );
  }
  try {
    final result = DateTime.utc(year, month, day, hour, minute, second);
    // DateTime.utc normalizes an out-of-range component instead of
    // rejecting it (e.g. 31.2.2026 quietly becomes a date in March), so a
    // malformed row would otherwise import with a shifted timestamp and
    // incorrectly participate in dive matching. Verify every field
    // round-tripped exactly before trusting the result.
    if (result.year != year ||
        result.month != month ||
        result.day != day ||
        result.hour != hour ||
        result.minute != minute ||
        result.second != second) {
      throw NavTrackParseException(
        'Row $rowNumber: invalid calendar date/time "$dateText $timeText"',
        reason: NavTrackParseReason.badData,
      );
    }
    return result.millisecondsSinceEpoch ~/ 1000;
  } on ArgumentError {
    throw NavTrackParseException(
      'Row $rowNumber: unparseable date/time "$dateText $timeText"',
      reason: NavTrackParseReason.badData,
    );
  }
}
