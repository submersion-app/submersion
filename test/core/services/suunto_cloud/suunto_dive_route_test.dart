import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/suunto_cloud/suunto_dive_route.dart';
import 'package:submersion/features/nav_track/domain/nav_track_point_codec.dart'
    show kMaxNavTrackPointCount;

int? _ms(Map<String, dynamic> s) {
  final iso = s['TimeISO8601'] as String?;
  return iso == null ? null : DateTime.parse(iso).millisecondsSinceEpoch;
}

Map<String, dynamic> _routeSample(int second, num x, num y, num z) => {
  'TimeISO8601': '2026-04-19T10:00:${second.toString().padLeft(2, '0')}.000Z',
  'DiveRoute': {'X': x, 'Y': y, 'Z': z},
};

SuuntoDiveRoute? _parse(
  List<Map<String, dynamic>> samples, {
  Duration correction = Duration.zero,
  double? lat,
  double? lon,
}) => SuuntoDiveRouteParser.parse(
  samples,
  timestampMs: _ms,
  clockCorrection: correction,
  originLatitude: lat,
  originLongitude: lon,
);

void main() {
  final t0 = DateTime.utc(2026, 4, 19, 10).millisecondsSinceEpoch ~/ 1000;

  Map<String, dynamic> depthSample(int second, num depth) => {
    'TimeISO8601': '2026-04-19T10:00:${second.toString().padLeft(2, '0')}.000Z',
    'Depth': depth,
  };

  test('maps X to east and Y to north, one point per route sample', () {
    final route = _parse(
      [
        depthSample(0, 2.0),
        _routeSample(1, 1.5, 2.5, -9),
        _routeSample(2, 3.0, 5.0, -9),
        depthSample(4, 6.0),
      ],
      lat: 47.2,
      lon: -2.9,
    )!;

    expect(route.points, hasLength(2));
    expect(route.points[0].east, 1.5);
    expect(route.points[0].north, 2.5);
    expect(route.points.map((p) => p.timestamp), [t0 + 1, t0 + 2]);
    expect(route.originLatitude, 47.2);
    expect(route.originLongitude, -2.9);
  });

  // Suunto's Z is up-positive and reads about 1.024 x depth + 0.35 m below
  // the surface (measured on real Nautic S exports, #1445), so the vertical
  // comes from the dive's own Depth channel, interpolated to each route
  // sample, rather than from Z.
  test('takes depth from the Depth channel, interpolated in time', () {
    final route = _parse([
      depthSample(0, 2.0),
      _routeSample(1, 0, 0, -50),
      _routeSample(2, 1, 1, -50),
      _routeSample(3, 2, 2, -50),
      depthSample(4, 6.0),
    ])!;

    expect(route.points.map((p) => p.depth), [3.0, 4.0, 5.0]);
  });

  test('holds the nearest depth outside the Depth channel span', () {
    final route = _parse([
      _routeSample(0, 0, 0, -50),
      depthSample(1, 4.0),
      depthSample(2, 8.0),
      _routeSample(3, 1, 1, -50),
    ])!;

    expect(route.points.map((p) => p.depth), [4.0, 8.0]);
  });

  test('falls back to -Z when the export has no Depth channel', () {
    final route = _parse([
      _routeSample(0, 0, 0, 0.3),
      _routeSample(1, 1, 1, -5.0),
      _routeSample(2, 2, 2, -6.0),
    ])!;

    expect(route.points.map((p) => p.depth), [0.0, 5.0, 6.0]);
  });

  test('applies the clock correction to every timestamp', () {
    final route = _parse([
      _routeSample(0, 0, 0, 1),
      _routeSample(1, 1, 1, 1),
    ], correction: const Duration(hours: -2))!;

    expect(route.points.map((p) => p.timestamp), [t0 - 7200, t0 - 7199]);
  });

  test('drops points with a missing or non-finite coordinate', () {
    final route = _parse([
      _routeSample(0, 0, 0, 1),
      {
        'TimeISO8601': '2026-04-19T10:00:01.000Z',
        'DiveRoute': {'X': 1, 'Y': null, 'Z': 1},
      },
      _routeSample(2, double.nan, 1, 1),
      _routeSample(3, 2, 2, 1),
    ])!;

    expect(route.points.map((p) => p.timestamp), [t0, t0 + 3]);
  });

  test('drops a point whose timestamp goes backwards, keeps equal ones', () {
    final route = _parse([
      _routeSample(0, 0, 0, 1),
      _routeSample(2, 1, 1, 1),
      _routeSample(1, 9, 9, 1),
      _routeSample(2, 2, 2, 1),
    ])!;

    expect(route.points.map((p) => p.east), [0, 1, 2]);
  });

  test('drops a sample with no timestamp', () {
    final route = _parse([
      _routeSample(0, 0, 0, 1),
      {
        'DiveRoute': {'X': 5, 'Y': 5, 'Z': 1},
      },
      _routeSample(1, 1, 1, 1),
    ])!;

    expect(route.points, hasLength(2));
  });

  test('returns null with fewer than two usable points', () {
    expect(_parse([_routeSample(0, 0, 0, 1)]), isNull);
    expect(_parse(const []), isNull);
  });

  test('returns null above the storable point cap', () {
    final start = DateTime.utc(2026, 4, 19);
    final samples = [
      for (var i = 0; i <= kMaxNavTrackPointCount; i++)
        {
          'TimeISO8601': start.add(Duration(seconds: i)).toIso8601String(),
          'DiveRoute': const {'X': 0, 'Y': 0, 'Z': 1},
        },
    ];
    expect(_parse(samples), isNull);
  });
}
