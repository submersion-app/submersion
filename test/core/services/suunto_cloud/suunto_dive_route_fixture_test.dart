import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

/// A real Suunto Nautic S dive (18 Aug 2026, 44 min, 21.2 m) exported from
/// the Suunto app and shared on #1445, trimmed to the channels the importer
/// reads: every Depth sample, and the DiveRoute densely over the first four
/// minutes and the mid-dive surfacing, every eighth sample elsewhere.
void main() {
  late SuuntoFileReadResult result;

  setUpAll(() {
    final file = File(
      p.join('test', 'fixtures', 'suunto', 'nautic_s_dive_route.json'),
    );
    result = readSuuntoJsonFile(
      SuuntoJsonFile(name: 'nautic.json', bytes: file.readAsBytesSync()),
    );
  });

  int epochSeconds(DateTime wallClock) =>
      wallClock.millisecondsSinceEpoch ~/ 1000;

  test('reads the dive and its route', () {
    expect(result.rejection, isNull);
    expect(result.dive!.route!.points, hasLength(586));
  });

  test('files the dive at the watch clock (10:05, not the app display)', () {
    expect(
      result.dive!.dive.startTime,
      DateTime.utc(2026, 8, 18, 10, 5, 11, 650),
    );
  });

  test('starts the route at its own origin, on the dive clock', () {
    final first = result.dive!.route!.points.first;

    expect(first.east, 0);
    expect(first.north, 0);
    expect(first.timestamp, epochSeconds(DateTime.utc(2026, 8, 18, 10, 5, 42)));
  });

  test('anchors the route at DiveRouteOrigin', () {
    final route = result.dive!.route!;

    expect(route.originLatitude, closeTo(47.4105797, 1e-6));
    expect(route.originLongitude, closeTo(-3.0220017, 1e-6));
  });

  test('takes depth from the Depth channel, not the fresh-water Z', () {
    final depths = result.dive!.route!.points.map((p) => p.depth).toList();

    expect(depths.every((d) => d >= 0), isTrue);
    // The deepest Depth reading is 21.07 m; Z would put it near 21.9 m.
    expect(depths.reduce(math.max), inInclusiveRange(20.0, 21.07));
  });

  test('pauses through the mid-dive surfacing and resumes in place', () {
    final points = result.dive!.route!.points;
    final gaps = [
      for (var i = 1; i < points.length; i++)
        if (points[i].timestamp - points[i - 1].timestamp > 250) i,
    ];

    // A ~5 min surface interval leaves no route samples, and Suunto picks
    // the route up at the same X/Y (it does not use the surface GPS fixes).
    final resume = gaps.last;
    final before = points[resume - 1];
    final after = points[resume];
    expect(after.timestamp - before.timestamp, greaterThan(280));
    expect(
      math.sqrt(
        math.pow(after.east - before.east, 2) +
            math.pow(after.north - before.north, 2),
      ),
      lessThan(0.5),
    );
  });

  // The 3D view draws only a route's active range, cut at what looks like a
  // GPS-fix jump (a Seacraft console's surfacing). Suunto's surface gaps
  // resume in place, so nothing may be cut from this route.
  test('keeps the whole route in the 3D path, surface gaps included', () {
    final points = result.dive!.route!.points;

    expect(NavTrackCorrector.activeRange(points), (
      start: 0,
      end: points.length - 1,
    ));
  });
}
