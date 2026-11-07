import 'dart:typed_data';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_csv_parser.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_marker.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_source_file_codec.dart';

final _log = LoggerService.forClass(NavTrackSourceMarkers);

/// What one stored original file says about its recording: how many samples
/// it parses to, the first and last of their timestamps, and its markers.
/// A file that cannot be read keeps a count of -1 and no markers.
typedef _FileReading = ({
  int pointCount,
  int firstTimestamp,
  int lastTimestamp,
  List<NavTrackMarker> markers,
});

const _FileReading _unreadable = (
  pointCount: -1,
  firstTimestamp: 0,
  lastTimestamp: 0,
  markers: [],
);

/// The console's markers in a route's stored original file (issue #4231).
///
/// Read from the file rather than stored on their own, and handed out only
/// while the stored points still derive from that file: same sample count,
/// same first and last timestamp. A parser change that maps rows to samples
/// differently, or a sync conflict that kept the points of one side and the
/// file of the other, would otherwise put every marker on the wrong sample.
class NavTrackSourceMarkers {
  const NavTrackSourceMarkers._();

  /// Readings of files already inflated and parsed, keyed by route and by
  /// the file's own content, so a rename, a relink, a saved alignment or a
  /// synced stamp does not parse an unchanged file again, and an unreadable
  /// file is reported once rather than on every read. Bounded: only the
  /// routes read most recently stay.
  static final _cache = <(String, int, int, int), _FileReading>{};
  static const int _cacheSize = 16;

  /// The markers [blob] (a stored `source_file`) holds for [routeId], or
  /// none when the file cannot be read or [points] no longer derive from it.
  static List<NavTrackMarker> markersFor({
    required String routeId,
    required Uint8List blob,
    required List<NavTrackPoint> points,
  }) {
    if (blob.isEmpty || points.isEmpty) return const [];
    final reading = _read(routeId, blob);
    final matches =
        reading.pointCount == points.length &&
        reading.firstTimestamp == points.first.timestamp &&
        reading.lastTimestamp == points.last.timestamp;
    return matches ? reading.markers : const [];
  }

  static _FileReading _read(String routeId, Uint8List blob) {
    final key = _keyOf(routeId, blob);
    final cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached;
    final reading = _parse(routeId, blob);
    _cache.removeWhere((k, _) => k.$1 == routeId);
    if (_cache.length >= _cacheSize) _cache.remove(_cache.keys.first);
    return _cache[key] = reading;
  }

  /// The blob's length and its last eight bytes: a gzip member ends with the
  /// CRC-32 and the size of what it holds, so these tell two files apart
  /// without hashing the whole blob. Read as two 32-bit words, which the web
  /// build can represent exactly.
  static (String, int, int, int) _keyOf(String routeId, Uint8List blob) {
    if (blob.length < 8) return (routeId, blob.length, 0, 0);
    final trailer = ByteData.sublistView(blob, blob.length - 8);
    return (
      routeId,
      blob.length,
      trailer.getUint32(0, Endian.little),
      trailer.getUint32(4, Endian.little),
    );
  }

  static _FileReading _parse(String routeId, Uint8List blob) {
    try {
      final parsed = parseSeacraftEncCsv(decodeNavTrackSourceFile(blob));
      return (
        pointCount: parsed.points.length,
        firstTimestamp: parsed.points.first.timestamp,
        lastTimestamp: parsed.points.last.timestamp,
        markers: parsed.markers,
      );
    } on NavTrackSourceFileCodecException catch (e, stackTrace) {
      _log.error(
        'Unreadable source file on nav track $routeId; showing no markers',
        error: e,
        stackTrace: stackTrace,
      );
    } on NavTrackParseException catch (e, stackTrace) {
      _log.error(
        'Unparseable source file on nav track $routeId; showing no markers',
        error: e,
        stackTrace: stackTrace,
      );
    }
    return _unreadable;
  }
}
