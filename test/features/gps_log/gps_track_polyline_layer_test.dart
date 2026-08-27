import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart';

GpsTrackPoint p(int t) =>
    GpsTrackPoint(timestamp: t, latitude: t * 0.001, longitude: 0.0);

TrackRun run(int bucket, int count) => TrackRun(
  points: List.generate(count, (i) => p(bucket * 100 + i)),
  bucket: bucket,
);

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

  group('trackBucketColors', () {
    test('returns one colour per bucket', () {
      final colors = trackBucketColors(scheme, TrackColorMode.speed, 8);
      expect(colors.length, 8);
    });

    test('produces visually distinct endpoints', () {
      final colors = trackBucketColors(scheme, TrackColorMode.speed, 8);
      expect(colors.first, isNot(equals(colors.last)));
    });

    test('uniform mode returns a single colour', () {
      final colors = trackBucketColors(scheme, TrackColorMode.uniform, 8);
      expect(colors.length, 1);
    });
  });

  group('buildTrackPolylines', () {
    test('emits one polyline per run', () {
      final runs = [run(0, 3), run(3, 4), run(7, 2)];
      final lines = buildTrackPolylines(
        runs: runs,
        mode: TrackColorMode.speed,
        scheme: scheme,
      );
      expect(lines.length, 3);
    });

    test('carries the run index as hitValue for tap resolution', () {
      final runs = [run(0, 3), run(3, 4)];
      final lines = buildTrackPolylines(
        runs: runs,
        mode: TrackColorMode.speed,
        scheme: scheme,
      );
      expect(lines[0].hitValue, 0);
      expect(lines[1].hitValue, 1);
    });

    test('maps each run to the colour for its bucket', () {
      final colors = trackBucketColors(scheme, TrackColorMode.speed, 8);
      final runs = [run(0, 2), run(7, 2)];
      final lines = buildTrackPolylines(
        runs: runs,
        mode: TrackColorMode.speed,
        scheme: scheme,
      );
      expect(lines[0].color, colors[0]);
      expect(lines[1].color, colors[7]);
    });

    test('uniform mode honours an explicit uniformColor override', () {
      final runs = [run(0, 3)];
      final lines = buildTrackPolylines(
        runs: runs,
        mode: TrackColorMode.uniform,
        scheme: scheme,
        uniformColor: const Color(0xFF123456),
      );
      expect(lines.single.color, const Color(0xFF123456));
    });

    test('converts every point to a LatLng in order', () {
      final runs = [run(0, 3)];
      final lines = buildTrackPolylines(
        runs: runs,
        mode: TrackColorMode.uniform,
        scheme: scheme,
      );
      expect(lines.single.points.length, 3);
      expect(lines.single.points.first.latitude, closeTo(0.0, 1e-9));
    });

    test('returns empty for no runs', () {
      final lines = buildTrackPolylines(
        runs: const [],
        mode: TrackColorMode.speed,
        scheme: scheme,
      );
      expect(lines, isEmpty);
    });

    test('clamps an out-of-range bucket rather than throwing', () {
      final lines = buildTrackPolylines(
        runs: [run(99, 2)],
        mode: TrackColorMode.speed,
        scheme: scheme,
      );
      expect(lines.length, 1);
    });
  });
}
