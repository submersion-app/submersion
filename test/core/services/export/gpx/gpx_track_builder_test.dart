import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/gpx/gpx_track_builder.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

GpsTrack _track({
  int tzOffsetMinutes = 0,
  String? name,
  int? trimStart,
  int? trimEnd,
}) {
  // 2026-05-22 08:00:00 wall clock.
  final startSec = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch ~/ 1000;
  return GpsTrack(
    id: 'track-1',
    startTime: startSec * 1000,
    endTime: (startSec + 120) * 1000,
    tzOffsetMinutes: tzOffsetMinutes,
    name: name,
    trimStartTime: trimStart,
    trimEndTime: trimEnd,
    pointCount: 3,
    points: [
      GpsTrackPoint(
        timestamp: startSec,
        latitude: 20.5,
        longitude: -87.25,
        accuracy: 5.0,
      ),
      GpsTrackPoint(
        timestamp: startSec + 60,
        latitude: 20.51,
        longitude: -87.26,
      ),
      GpsTrackPoint(
        timestamp: startSec + 120,
        latitude: 20.52,
        longitude: -87.27,
      ),
    ],
  );
}

void main() {
  test('emits a well-formed gpx root with the creator', () {
    final gpx = buildGpxDocument(_track(), creator: 'Submersion');
    expect(gpx, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
    expect(gpx, contains('<gpx'));
    expect(gpx, contains('version="1.1"'));
    expect(gpx, contains('creator="Submersion"'));
    expect(gpx, contains('</gpx>'));
  });

  test('emits one trkpt per fix with lat and lon attributes', () {
    final gpx = buildGpxDocument(_track(), creator: 'Submersion');
    expect('<trkpt'.allMatches(gpx).length, 3);
    expect(gpx, contains('lat="20.5"'));
    expect(gpx, contains('lon="-87.25"'));
  });

  test('writes real UTC times for a zero offset', () {
    final gpx = buildGpxDocument(_track(), creator: 'Submersion');
    expect(gpx, contains('<time>2026-05-22T08:00:00Z</time>'));
  });

  test('subtracts tzOffsetMinutes to recover real UTC', () {
    // Recorded at 08:00 local in UTC-5, so the real instant is 13:00 UTC.
    final gpx = buildGpxDocument(
      _track(tzOffsetMinutes: -300),
      creator: 'Submersion',
    );
    expect(gpx, contains('<time>2026-05-22T13:00:00Z</time>'));
  });

  test('handles a positive offset', () {
    // 08:00 local in UTC+8 is 00:00 real UTC.
    final gpx = buildGpxDocument(
      _track(tzOffsetMinutes: 480),
      creator: 'Submersion',
    );
    expect(gpx, contains('<time>2026-05-22T00:00:00Z</time>'));
  });

  test('includes the track name when set', () {
    final gpx = buildGpxDocument(
      _track(name: 'Palancar morning'),
      creator: 'Submersion',
    );
    expect(gpx, contains('<name>Palancar morning</name>'));
  });

  test('escapes XML metacharacters in the name', () {
    final gpx = buildGpxDocument(
      _track(name: 'Reef & <Wall>'),
      creator: 'Submersion',
    );
    // Only & and < must be escaped in text content; a bare > is legal XML,
    // and the xml package leaves it as-is.
    expect(gpx, contains('Reef &amp; &lt;Wall>'));
    // The point of escaping: no spurious element is introduced.
    expect(gpx, isNot(contains('<Wall>')));
  });

  test('emits hdop from accuracy where present', () {
    final gpx = buildGpxDocument(_track(), creator: 'Submersion');
    expect(gpx, contains('<hdop>5.0</hdop>'));
    // Only the first fix carries accuracy.
    expect('<hdop>'.allMatches(gpx).length, 1);
  });

  test('honours trim bounds via effectivePoints', () {
    final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final gpx = buildGpxDocument(
      _track(trimStart: startMs + 60000),
      creator: 'Submersion',
    );
    // The 08:00 fix is trimmed away; two remain.
    expect('<trkpt'.allMatches(gpx).length, 2);
  });

  test('emits an empty trkseg for a track with no points', () {
    const empty = GpsTrack(id: 'e', startTime: 0, endTime: 1);
    final gpx = buildGpxDocument(empty, creator: 'Submersion');
    expect(gpx, contains('<trkseg'));
    expect(gpx, isNot(contains('<trkpt')));
  });

  test('realUtcFrom is the inverse of the import conversion', () {
    // Export and re-import must compose to identity or a round trip drifts.
    const offset = -300;
    final wallClockSec =
        DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch ~/ 1000;
    final realUtc = realUtcFrom(wallClockSec, offset);
    final backToWallClock =
        realUtc.add(const Duration(minutes: offset)).millisecondsSinceEpoch ~/
        1000;
    expect(backToWallClock, wallClockSec);
  });
}
