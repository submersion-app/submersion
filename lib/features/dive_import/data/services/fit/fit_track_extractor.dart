import 'package:fit_tool/fit_tool.dart';

import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';

/// Harvests the full position stream from a FIT file's record messages.
///
/// fit_parser_service already walks these records reading positionLat and
/// positionLong, but keeps only the LAST one as the dive's exit fix - the
/// rest of the stream is discarded. This collects all of it into a track.
///
/// Positions come back from fit_tool already in degrees (the field carries
/// the semicircle scale), so no conversion is applied here. Applying
/// semicircleToDegrees a second time would collapse every coordinate toward
/// zero.
///
/// Returns null when fewer than two positioned records exist - one fix is a
/// point, not a track.
ParsedTrack? extractFitTrack(List<RecordMessage> records) {
  final fixes = <ParsedFix>[];

  for (final record in records) {
    final lat = record.positionLat;
    final lon = record.positionLong;
    final timestampMs = record.timestamp;
    if (lat == null || lon == null || timestampMs == null) continue;

    // A corrupt record should cost one fix, not the whole track.
    try {
      validateCoordinate(lat, lon);
    } on TrackParseException {
      continue;
    }

    fixes.add((
      utc: DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true),
      lat: lat,
      lon: lon,
      accuracy: null,
    ));
  }

  if (fixes.length < 2) return null;
  fixes.sort((a, b) => a.utc.compareTo(b.utc));
  return ParsedTrack(fixes: List.unmodifiable(fixes));
}
