import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_csv_parser.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';

NavTrackPoint _p({
  int timestamp = 0,
  double north = 0,
  double east = 0,
  double depth = 0,
  double? distance,
  double? speed,
}) => NavTrackPoint(
  timestamp: timestamp,
  north: north,
  east: east,
  depth: depth,
  distance: distance,
  speed: speed,
);

void main() {
  group('NavTrackStats.of', () {
    test('reads distance, depth, speed and duration from a simple route', () {
      final stats = NavTrackStats.of([
        _p(timestamp: 0, depth: 1, distance: 0, speed: 0.1),
        _p(timestamp: 30, depth: 10, distance: 50, speed: 0.5),
        _p(timestamp: 60, depth: 25, distance: 120, speed: 0.9),
        _p(timestamp: 300, depth: 3, distance: 1000, speed: 0.2),
      ]);
      expect(stats.totalDistance, 1000);
      expect(stats.maxDepth, 25);
      expect(stats.maxSpeed, closeTo(0.9, 1e-9));
      expect(stats.avgSpeed, closeTo((0.1 + 0.5 + 0.9 + 0.2) / 4, 1e-9));
      expect(stats.durationSeconds, 300);
      expect(stats.pointCount, 4);
    });

    test('falls back to path length for total distance when the device '
        'channel is missing', () {
      final stats = NavTrackStats.of([
        _p(timestamp: 0, north: 0, east: 0),
        _p(timestamp: 10, north: 100, east: 0),
        _p(timestamp: 20, north: 100, east: 100),
      ]);
      expect(stats.totalDistance, closeTo(200, 1e-9));
    });

    test('falls back to path length when the device distance channel is '
        'not monotone', () {
      final stats = NavTrackStats.of([
        _p(timestamp: 0, north: 0, east: 0, distance: 0),
        _p(timestamp: 10, north: 100, east: 0, distance: 500),
        _p(timestamp: 20, north: 200, east: 0, distance: 10),
      ]);
      expect(stats.totalDistance, closeTo(200, 1e-9));
    });

    test('ignores null speed readings when averaging', () {
      final stats = NavTrackStats.of([
        _p(timestamp: 0, speed: 1.0),
        _p(timestamp: 10, speed: null),
        _p(timestamp: 20, speed: 3.0),
      ]);
      expect(stats.avgSpeed, closeTo(2.0, 1e-9));
      expect(stats.maxSpeed, closeTo(3.0, 1e-9));
    });

    test('reports null speed stats when no sample has a speed reading', () {
      final stats = NavTrackStats.of([_p(timestamp: 0), _p(timestamp: 10)]);
      expect(stats.maxSpeed, isNull);
      expect(stats.avgSpeed, isNull);
    });

    test('handles a single-sample route without dividing by zero', () {
      final stats = NavTrackStats.of([_p(timestamp: 5, depth: 2, distance: 0)]);
      expect(stats.durationSeconds, 0);
      expect(stats.totalDistance, 0);
      expect(stats.pointCount, 1);
    });

    test('stops at the last pre-fix-event sample on a recording with a '
        'surface GPS fix, instead of running to the end of the raw file '
        '(design spec: "statistics must stop at the last dead-reckoned '
        'sample")', () {
      final points = parseSeacraftEncCsv(
        File(
          'test/fixtures/nav_tracks/seacraft_enc3_gps_fix.csv',
        ).readAsBytesSync(),
      ).points;
      final activeEnd = NavTrackCorrector.activeRangeEndIndex(points);
      // The fixture does have a fix event partway through, so the active
      // range must end well before the raw file's last sample.
      expect(activeEnd, lessThan(points.length - 1));
      final expectedDuration =
          points[activeEnd].timestamp - points.first.timestamp;
      final rawDuration = points.last.timestamp - points.first.timestamp;

      final stats = NavTrackStats.of(points);

      expect(stats.durationSeconds, expectedDuration);
      expect(stats.durationSeconds, lessThan(rawDuration));
    });

    test('handles an empty route', () {
      final stats = NavTrackStats.of(const []);
      expect(stats.pointCount, 0);
      expect(stats.durationSeconds, 0);
      expect(stats.totalDistance, 0);
      expect(stats.maxDepth, 0);
      expect(stats.maxSpeed, isNull);
      expect(stats.avgSpeed, isNull);
    });
  });
}
