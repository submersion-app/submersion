import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

GpsTrackPoint p(int t) =>
    GpsTrackPoint(timestamp: t, latitude: 0.0, longitude: t * 0.001);

GpsTrack trackWith({int? trimStart, int? trimEnd}) => GpsTrack(
  id: 'track-1',
  // Points are epoch SECONDS; trim bounds are epoch MILLISECONDS.
  startTime: 100000,
  endTime: 400000,
  points: [p(100), p(200), p(300), p(400)],
  trimStartTime: trimStart,
  trimEndTime: trimEnd,
);

void main() {
  group('effectivePoints', () {
    test('returns every point when no trim is set', () {
      expect(trackWith().effectivePoints.length, 4);
    });

    test('drops points before the trim start', () {
      final track = trackWith(trimStart: 200000);
      expect(track.effectivePoints.map((e) => e.timestamp).toList(), [
        200,
        300,
        400,
      ]);
    });

    test('drops points after the trim end', () {
      final track = trackWith(trimEnd: 300000);
      expect(track.effectivePoints.map((e) => e.timestamp).toList(), [
        100,
        200,
        300,
      ]);
    });

    test('applies both bounds together', () {
      final track = trackWith(trimStart: 200000, trimEnd: 300000);
      expect(track.effectivePoints.map((e) => e.timestamp).toList(), [
        200,
        300,
      ]);
    });

    test('never mutates the underlying points list', () {
      final track = trackWith(trimStart: 200000);
      track.effectivePoints;
      expect(track.points.length, 4);
    });

    test('returns empty when the trim window excludes everything', () {
      final track = trackWith(trimStart: 500000);
      expect(track.effectivePoints, isEmpty);
    });
  });

  group('new v145 fields', () {
    test('source defaults to phone', () {
      expect(const GpsTrack(id: 'a', startTime: 0).source, 'phone');
    });

    test('copyWith carries the new fields', () {
      final track = trackWith().copyWith(
        source: 'gpx',
        sourceRef: 'day3.gpx',
        name: 'Palancar',
        trimStartTime: 200000,
        trimEndTime: 300000,
      );
      expect(track.source, 'gpx');
      expect(track.sourceRef, 'day3.gpx');
      expect(track.name, 'Palancar');
      expect(track.effectivePoints.length, 2);
    });
  });
}
