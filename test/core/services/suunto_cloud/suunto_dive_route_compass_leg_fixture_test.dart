import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

/// A real Suunto Nautic S shore dive in Dahab (9 Oct 2026, 49 min, 27.4 m)
/// shared on #1445 to settle the DiveRoute frame. From 30:00 to 32:00 the
/// diver held 260 degrees magnetic (about 264.5 true) on the watch compass at
/// 11-12 m, and the deep section ran offshore, south-east of a beach that lies
/// to the north-west of the entry.
///
/// Trimmed to the channels the importer reads: every Depth sample, and the
/// DiveRoute densely over the compass leg and the final surfacing, every
/// eighth sample elsewhere. The export has no entry fix.
void main() {
  late SuuntoFileReadResult result;

  setUpAll(() {
    final file = File(
      p.join('test', 'fixtures', 'suunto', 'nautic_s_compass_leg.json'),
    );
    result = readSuuntoJsonFile(
      SuuntoJsonFile(name: 'nautic.json', bytes: file.readAsBytesSync()),
    );
  });

  int epochSeconds(DateTime wallClock) =>
      wallClock.millisecondsSinceEpoch ~/ 1000;

  List<NavTrackPoint> points() => result.dive!.route!.points;

  test('reads the dive and its route', () {
    expect(result.rejection, isNull);
    expect(points(), hasLength(439));
  });

  // A west leg rules out an X/Y swap (it would read 0 or 180), an east-west
  // mirror (90) and a 180-degree turn (90). It cannot tell Y from -Y; the
  // offshore test below does that.
  test('reads the 260-degree compass leg as a straight westward swim', () {
    final legStart = epochSeconds(DateTime.utc(2026, 10, 9, 13, 30, 12));
    final legEnd = epochSeconds(DateTime.utc(2026, 10, 9, 13, 32, 12));
    final leg = [
      for (final point in points())
        if (point.timestamp >= legStart && point.timestamp <= legEnd) point,
    ];
    final dEast = leg.last.east - leg.first.east;
    final dNorth = leg.last.north - leg.first.north;
    final bearing = (math.atan2(dEast, dNorth) * 180 / math.pi + 360) % 360;
    final chord = math.sqrt(dEast * dEast + dNorth * dNorth);
    var path = 0.0;
    for (var i = 1; i < leg.length; i++) {
      path += math.sqrt(
        math.pow(leg[i].east - leg[i - 1].east, 2) +
            math.pow(leg[i].north - leg[i - 1].north, 2),
      );
    }

    expect(leg.length, greaterThan(90));
    expect(chord, closeTo(20.2, 0.5));
    // The route reads 270.2; the course held was about 264.5 true.
    expect(bearing, inInclusiveRange(260.0, 280.0));
    expect(chord / path, greaterThan(0.95));
  });

  test('puts the deep section offshore, south-east of the entry', () {
    final deepest = points().reduce((a, b) => a.depth >= b.depth ? a : b);

    // Under a north-south mirror this would sit north-east, on the beach.
    expect(deepest.east, greaterThan(50));
    expect(deepest.north, lessThan(-20));
  });

  test('anchors the route and the entry at DiveRouteOrigin', () {
    final route = result.dive!.route!;

    expect(points().first.east, 0);
    expect(points().first.north, 0);
    expect(route.originLatitude, closeTo(28.4374695, 1e-6));
    expect(route.originLongitude, closeTo(34.4591751, 1e-6));
    expect(result.dive!.dive.entryLatitude, route.originLatitude);
    expect(result.dive!.dive.entryLongitude, route.originLongitude);
  });

  test('takes depth from the Depth channel, not the fresh-water Z', () {
    final depths = points().map((p) => p.depth).toList();

    expect(depths.every((d) => d >= 0), isTrue);
    // The deepest Depth reading is 27.39 m; Z would put it near 28.2 m.
    expect(depths.reduce(math.max), inInclusiveRange(26.5, 27.39));
  });

  test('resumes in place after the 32 s gap before surfacing', () {
    final all = points();
    final resume = [
      for (var i = 1; i < all.length; i++)
        if (all[i].timestamp - all[i - 1].timestamp > 20) i,
    ].single;
    final before = all[resume - 1];
    final after = all[resume];

    expect(after.timestamp - before.timestamp, inInclusiveRange(30, 34));
    expect(
      math.sqrt(
        math.pow(after.east - before.east, 2) +
            math.pow(after.north - before.north, 2),
      ),
      lessThan(1.0),
    );
    expect(NavTrackCorrector.activeRange(all), (start: 0, end: all.length - 1));
  });
}
