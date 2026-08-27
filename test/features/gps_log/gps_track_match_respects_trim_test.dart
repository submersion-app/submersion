import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/gps_track_matcher.dart';

/// The match sweep is the one consumer of a track that WRITES and syncs dive
/// coordinates, so a trim it ignores is a trim that silently does nothing
/// where it matters most.
///
/// Scenario: 07:00 drive to the marina inland, 09:00-11:00 on the reef. The
/// diver trims the drive away.
GpsTrack _track({int? trimStart}) {
  final base = DateTime.utc(2026, 5, 22, 7).millisecondsSinceEpoch;
  return GpsTrack(
    id: 'track-1',
    startTime: base,
    endTime: DateTime.utc(2026, 5, 22, 11).millisecondsSinceEpoch,
    trimStartTime: trimStart,
    pointCount: 3,
    points: [
      // Inland, on the highway.
      GpsTrackPoint(timestamp: base ~/ 1000, latitude: 20.03, longitude: -87.5),
      GpsTrackPoint(
        timestamp: DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch ~/ 1000,
        latitude: 30.0,
        longitude: -87.0,
      ),
      GpsTrackPoint(
        timestamp: DateTime.utc(2026, 5, 22, 11).millisecondsSinceEpoch ~/ 1000,
        latitude: 30.1,
        longitude: -87.1,
      ),
    ],
  );
}

final _nineAm = DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch;
final _sevenAm = DateTime.utc(2026, 5, 22, 7).millisecondsSinceEpoch;

void main() {
  test('an untrimmed track covers a dive entered during the drive', () {
    expect(GpsTrackMatcher.trackCovering([_track()], _sevenAm), isNotNull);
  });

  test('a trimmed track no longer covers the trimmed-away leg', () {
    final trimmed = _track(
      trimStart: DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch,
    );
    // 07:00 is well outside the 30-minute tolerance around a 09:00 start.
    expect(GpsTrackMatcher.trackCovering([trimmed], _sevenAm), isNull);
  });

  test('a trimmed track still covers a dive inside the kept span', () {
    final trimmed = _track(
      trimStart: DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch,
    );
    expect(GpsTrackMatcher.trackCovering([trimmed], _nineAm), isNotNull);
  });

  test('positionAt over effectivePoints returns the reef, not the highway', () {
    final trimmed = _track(
      trimStart: DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch,
    );
    // Reading raw points would clamp to the 07:00 fix at latitude 20.03.
    final position = GpsTrackMatcher.positionAt(
      trimmed.effectivePoints,
      _nineAm ~/ 1000,
    );
    expect(position!.latitude, closeTo(30.0, 1e-9));
  });

  test('effectiveStartTime and effectiveEndTime honour the bounds', () {
    final trimmed = _track(
      trimStart: DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch,
    );
    expect(trimmed.effectiveStartTime, _nineAm);
    // No end trim set, so the recording end stands.
    expect(
      trimmed.effectiveEndTime,
      DateTime.utc(2026, 5, 22, 11).millisecondsSinceEpoch,
    );
  });
}
