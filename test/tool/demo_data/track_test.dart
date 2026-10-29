import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';

import '../../../tool/demo_data/src/seeders/demo_seeding.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import '../../helpers/test_database.dart';
import 'seed_harness.dart';

double _metres(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  double rad(double d) => d * pi / 180;
  final h =
      pow(sin(rad(lat2 - lat1) / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(rad(lon2 - lon1) / 2), 2);
  return 2 * r * asin(sqrt(h));
}

void main() {
  late DemoSeedContext ctx;

  setUpAll(() async {
    ctx = await seedContext();
    await seedAll(ctx);
  });

  tearDownAll(tearDownTestDatabase);

  test('every scooter dive has one route linked to it', () async {
    final scooter = ctx.plan.dives.where((d) => d.scooter).toList();
    expect(scooter, isNotEmpty);
    for (final d in scooter) {
      final routes = await NavTrackRepository().getForDive(
        ctx.diveId(d.number),
      );
      expect(routes, hasLength(1), reason: 'dive ${d.number}');
    }
  });

  test(
    "each route starts within the dive's runtime and follows its depth",
    () async {
      final repo = DiveRepository();
      for (final d in ctx.plan.dives.where((d) => d.scooter).take(6)) {
        final id = ctx.diveId(d.number);
        final dive = (await repo.getDivesByIds([id])).single;
        final route = (await NavTrackRepository().getForDive(
          id,
          includePoints: true,
        )).single;
        final start = asWallClockUtc(d.start).millisecondsSinceEpoch ~/ 1000;
        final first = route.points.first.timestamp;
        expect(first, greaterThanOrEqualTo(start), reason: 'dive ${d.number}');
        expect(
          first,
          lessThan(start + dive.runtime!.inSeconds),
          reason: 'dive ${d.number}',
        );
        final byTime = {for (final p in dive.profile) p.timestamp: p.depth};
        var compared = 0;
        for (final p in route.points) {
          final at = byTime[p.timestamp - start];
          if (at == null) continue;
          compared++;
          expect(
            (p.depth - at).abs(),
            lessThanOrEqualTo(1.0),
            reason: 'dive ${d.number}',
          );
        }
        expect(compared, greaterThan(10), reason: 'dive ${d.number}');
      }
    },
  );

  test('at least 20 boat tracks, each returning to its harbour', () async {
    final tracks = await GpsTrackRepository().getCompletedTracks(
      includePoints: true,
    );
    expect(tracks.length, greaterThanOrEqualTo(20));
    final sites = ctx.plan.sites;
    for (final t in tracks) {
      final a = t.points.first, b = t.points.last;
      expect(
        _metres(a.latitude, a.longitude, b.latitude, b.longitude),
        lessThan(100),
        reason: t.name,
      );
      final nearSite = t.points.any(
        (p) => sites.any(
          (s) =>
              _metres(p.latitude, p.longitude, s.latitude, s.longitude) < 300,
        ),
      );
      expect(nearSite, isTrue, reason: t.name);
    }
  });
}
