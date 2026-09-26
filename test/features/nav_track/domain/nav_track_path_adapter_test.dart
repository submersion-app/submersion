import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_path_adapter.dart';

NavTrackPoint _p({
  required int timestamp,
  required double north,
  required double east,
  required double depth,
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

NavTrack _route({
  required List<NavTrackPoint> points,
  NavTrackCorrection correction = const NavTrackCorrection(),
}) {
  final now = DateTime(2026, 9, 10);
  return NavTrack(
    id: 'route-1',
    source: NavTrackSource.seacraftEnc,
    startTime: points.isEmpty ? 0 : points.first.timestamp * 1000,
    endTime: points.isEmpty ? 0 : points.last.timestamp * 1000,
    pointCount: points.length,
    anchorLatitude: correction.anchor?.latitude,
    anchorLongitude: correction.anchor?.longitude,
    endMode: correction.endMode,
    endLatitude: correction.endPoint?.latitude,
    endLongitude: correction.endPoint?.longitude,
    trustFraction: correction.trustFraction,
    headingOffsetDeg: correction.headingOffsetDeg,
    points: points,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('NavTrackPathAdapter.toReckonedPath', () {
    test(
      'carries an underwater route through unchanged with no correction',
      () {
        final points = [
          for (var i = 0; i < 5; i++)
            _p(timestamp: 1000 + i * 10, north: i * 10.0, east: 0, depth: 5),
        ];

        final path = NavTrackPathAdapter.toReckonedPath(_route(points: points));

        expect(path.provenance, PathProvenance.measured);
        expect(path.sourceLabel, NavTrackSource.seacraftEnc.label);
        expect(path.points, hasLength(5));
        expect(path.points.first.timeSeconds, 0);
        expect(path.points.last.timeSeconds, 40);
        expect(path.points.last.north, 40.0);
        expect(path.durationSeconds, 40);
        expect(path.maxDepth, 5);
      },
    );

    test('re-bases timeSeconds to start at 0 for a non-zero timestamp', () {
      final points = [
        for (var i = 0; i < 3; i++)
          _p(timestamp: 1700000000 + i * 5, north: 0, east: i * 2.0, depth: 4),
      ];

      final path = NavTrackPathAdapter.toReckonedPath(_route(points: points));

      expect(path.points.first.timeSeconds, 0);
      expect(path.points.map((p) => p.timeSeconds), [0, 5, 10]);
    });

    test('drops samples from a fix event onward (never spans the jump)', () {
      // Underwater/surface samples, then a >50 m jump within 5 s at the
      // surface: NavTrackSegmenter classifies the jump onward as gpsFixed.
      final points = [
        _p(timestamp: 0, north: 0, east: 0, depth: 5),
        _p(timestamp: 10, north: 5, east: 0, depth: 0.1, distance: 5),
        // Fix event: >50 m step in <=5 s at the surface.
        _p(timestamp: 12, north: 400, east: 0, depth: 0.1, distance: 5),
        _p(timestamp: 20, north: 405, east: 0, depth: 0.1, distance: 5),
      ];

      final path = NavTrackPathAdapter.toReckonedPath(_route(points: points));

      // Only the two pre-jump samples survive.
      expect(path.points, hasLength(2));
      expect(path.points.last.north, 5);
      expect(path.durationSeconds, 10);
    });

    test(
      'applies the route\'s own correction (same_as_start closes the loop)',
      () {
        final points = [
          for (var i = 0; i < 5; i++)
            _p(
              timestamp: i * 10,
              north: i * 20.0,
              east: 0,
              depth: 5,
              distance: i * 20.0,
            ),
        ];
        final route = _route(
          points: points,
          correction: const NavTrackCorrection(
            endMode: NavTrackEndMode.sameAsStart,
          ),
        );

        final path = NavTrackPathAdapter.toReckonedPath(route);

        expect(path.points.first.north, closeTo(0, 1e-9));
        expect(path.points.last.north, closeTo(0, 1e-9));
      },
    );

    test(
      'never includes a sample from after a fix event even when the diver '
      're-descends later in the same recording (a later underwater run '
      'must not be stitched onto the pre-fix ribbon across the GPS jump)',
      () {
        final points = [
          _p(timestamp: 0, north: 0, east: 0, depth: 5),
          _p(timestamp: 10, north: 5, east: 0, depth: 0.1, distance: 5),
          // Fix event: >50 m step in <=5 s at the surface.
          _p(timestamp: 12, north: 400, east: 0, depth: 0.1, distance: 5),
          _p(timestamp: 20, north: 405, east: 0, depth: 0.1, distance: 5),
          // Re-descend: depth rises back above the surface threshold, so
          // the segmenter classifies this run as `underwater` again --
          // the adapter must still stop at the first fix event, not
          // resume the ribbon here.
          _p(timestamp: 30, north: 410, east: 0, depth: 6, distance: 200),
          _p(timestamp: 40, north: 420, east: 0, depth: 7, distance: 210),
        ];

        final path = NavTrackPathAdapter.toReckonedPath(_route(points: points));

        expect(path.points, hasLength(2));
        expect(path.points.last.north, 5);
        expect(path.durationSeconds, 10);
        for (final p in path.points) {
          expect(p.north, lessThan(400));
        }
      },
    );

    test('returns an empty measured path when the route has no points', () {
      final route = _route(points: const []);

      final path = NavTrackPathAdapter.toReckonedPath(route);

      expect(path.isEmpty, isTrue);
      expect(path.provenance, PathProvenance.measured);
    });
  });
}
