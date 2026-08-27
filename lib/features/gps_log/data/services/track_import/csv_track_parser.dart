import 'dart:typed_data';

import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_parser.dart';

/// Which CSV column holds which field.
///
/// CSV has no schema, so unlike GPX and KML this cannot be inferred with
/// confidence. [guessCsvMapping] proposes one; the import review step
/// presents it for confirmation rather than applying it silently.
class CsvColumnMapping {
  final int timeIndex;
  final int latIndex;
  final int lonIndex;
  final int? accuracyIndex;

  const CsvColumnMapping({
    required this.timeIndex,
    required this.latIndex,
    required this.lonIndex,
    this.accuracyIndex,
  });
}

const _kTimeHeaders = {'time', 'timestamp', 'datetime', 'date_time', 'utc'};
const _kLatHeaders = {'lat', 'latitude', 'y'};
const _kLonHeaders = {'lon', 'lng', 'long', 'longitude', 'x'};
const _kAccuracyHeaders = {'accuracy', 'hdop', 'precision', 'error'};

/// Shared RFC-4180 reader.
///
/// Splitting on bare commas shifted every column after a quoted field
/// containing one - a row like `...,"Boat, the",12.0,45.5,-80.1` silently
/// plotted a Georgian Bay track in the Gulf of Aden. This wrapper already
/// existed for the universal importer and handles quotes, embedded newlines,
/// and line-ending normalisation.
const _reader = CsvParser();

/// The header row, trimmed and unquoted.
List<String> readCsvHeaders(Uint8List bytes) {
  try {
    return _reader.parse(bytes).headers;
  } on CsvParseException catch (e) {
    throw TrackParseException(e.message);
  }
}

/// Proposes a mapping from common header names, or null when the required
/// three cannot be identified.
CsvColumnMapping? guessCsvMapping(List<String> headers) {
  int? find(Set<String> candidates) {
    for (var i = 0; i < headers.length; i++) {
      if (candidates.contains(headers[i].toLowerCase().trim())) return i;
    }
    return null;
  }

  final time = find(_kTimeHeaders);
  final lat = find(_kLatHeaders);
  final lon = find(_kLonHeaders);
  if (time == null || lat == null || lon == null) return null;

  return CsvColumnMapping(
    timeIndex: time,
    latIndex: lat,
    lonIndex: lon,
    accuracyIndex: find(_kAccuracyHeaders),
  );
}

ParsedTrack parseCsv(Uint8List bytes, CsvColumnMapping mapping) {
  final ParsedCsv parsed;
  try {
    parsed = _reader.parse(bytes);
  } on CsvParseException catch (e) {
    throw TrackParseException(e.message);
  }

  final fixes = <ParsedFix>[];
  var anyZoned = false;

  for (var i = 0; i < parsed.rows.length; i++) {
    final cells = parsed.rows[i];
    String? cell(int? index) {
      if (index == null || index >= cells.length) return null;
      final value = cells[index].trim();
      return value.isEmpty ? null : value;
    }

    final timeText = cell(mapping.timeIndex);
    final time = timeText == null ? null : parseFixTime(timeText);
    if (time == null) {
      throw TrackParseException(
        'Row ${i + 2}: unparseable time "$timeText"',
        reason: TrackParseReason.badData,
      );
    }
    if (time.zoned) anyZoned = true;

    final lat = double.tryParse(cell(mapping.latIndex) ?? '');
    final lon = double.tryParse(cell(mapping.lonIndex) ?? '');
    if (lat == null || lon == null) {
      throw TrackParseException(
        'Row ${i + 2}: unparseable coordinate',
        reason: TrackParseReason.badData,
      );
    }
    validateCoordinate(lat, lon);

    fixes.add((
      utc: time.time,
      lat: lat,
      lon: lon,
      accuracy: double.tryParse(cell(mapping.accuracyIndex) ?? ''),
    ));
  }

  if (fixes.isEmpty) {
    throw const TrackParseException(
      'No usable data rows',
      reason: TrackParseReason.noPositions,
    );
  }
  fixes.sort((a, b) => a.utc.compareTo(b.utc));
  return ParsedTrack(
    fixes: List.unmodifiable(fixes),
    timesAreWallClock: !anyZoned,
  );
}
