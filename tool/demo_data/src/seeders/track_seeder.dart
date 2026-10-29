import 'dart:math';

import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

import '../story/catalog.dart';
import '../story/destinations.dart';
import '../story/story_plan.dart';
import 'route_shapes.dart';
import 'seed_context.dart';

/// The underwater route of every scooter dive, logged by the scooter, and
/// the GPS track of a share of resort boat days: out from the harbour to
/// each site of the day and back.
class TrackSeeder implements DemoSeeder {
  @override
  String get name => 'tracks';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final sites = {for (final s in ctx.plan.sites) s.id: s};
    final routes = NavTrackRepository();
    var n = 0;
    for (final d in ctx.plan.dives.where((d) => d.scooter)) {
      final site = sites[d.siteId]!;
      await routes.insertImportedRoute(
        points: scooterRoute(
          RoutePattern.values[d.number % RoutePattern.values.length],
          samples: ctx.scooterProfiles[d.number]!,
          startEpochSeconds: _wallSeconds(d.start),
          random: ctx.random,
        ),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'demo-route-${++n}',
        deviceName: 'Seacraft Future',
        diveId: ctx.diveId(d.number),
        siteId: ctx.siteId(site.id),
        equipmentId: ctx.equipment['dpv'],
        diverId: DemoSeedContext.diverId,
        anchorLatitude: site.latitude,
        anchorLongitude: site.longitude,
      );
    }
    await _boatDays(ctx, sites);
  }

  Future<void> _boatDays(
    DemoSeedContext ctx,
    Map<String, CatalogSite> sites,
  ) async {
    final gps = GpsTrackRepository();
    for (final trip in ctx.plan.trips) {
      if (trip.destination.liveaboard || trip.destination.freshwater) {
        continue;
      }
      final dives = ctx.plan.dives.where((d) => d.tripId == trip.id && d.boat);
      if (dives.isEmpty) continue;
      // The harbour the boats leave from, a few kilometres off the sites.
      final first = sites[dives.first.siteId]!;
      final bearing = ctx.random.nextDouble() * 2 * pi;
      final km = 3 + ctx.random.nextDouble() * 9;
      final harbour = (
        first.latitude + km / 111.0 * cos(bearing),
        first.longitude +
            km / (111.0 * cos(first.latitude * pi / 180)) * sin(bearing),
      );
      final byDay = <DateTime, List<PlannedDive>>{};
      for (final d in dives) {
        byDay
            .putIfAbsent(
              DateTime(d.start.year, d.start.month, d.start.day),
              () => [],
            )
            .add(d);
      }
      for (final day in byDay.values) {
        if (ctx.random.nextDouble() >= 0.4) continue;
        final points = _boatDay(ctx, day, harbour, sites);
        await gps.insertImportedTrack(
          points: points,
          startTimeMs: points.first.timestamp * 1000,
          endTimeMs: points.last.timestamp * 1000,
          tzOffsetMinutes: utcOffsetOn(trip.destination, day.first.start),
          source: 'demo',
          name: 'Boat to ${sites[day.first.siteId]!.name}',
        );
      }
    }
  }

  /// One boat day: leave the harbour, run to each dive site at 20 km/h,
  /// drift on the mooring through the dive, and run home after the last.
  List<GpsTrackPoint> _boatDay(
    DemoSeedContext ctx,
    List<PlannedDive> dives,
    (double, double) harbour,
    Map<String, CatalogSite> sites,
  ) {
    final points = <GpsTrackPoint>[];
    var at = (harbour.$1, harbour.$2);
    var clock = _wallSeconds(dives.first.start) - 45 * 60;
    void runTo((double, double) to) {
      final metres = _metres(at, to);
      final steps = max(1, (metres / (20000 / 60)).ceil()); // 20 km/h
      for (var i = 1; i <= steps; i++) {
        final f = i / steps;
        points.add(
          GpsTrackPoint(
            timestamp: clock + i * 60,
            latitude: at.$1 + (to.$1 - at.$1) * f,
            longitude: at.$2 + (to.$2 - at.$2) * f,
          ),
        );
      }
      clock += steps * 60;
      at = to;
    }

    points.add(
      GpsTrackPoint(timestamp: clock, latitude: at.$1, longitude: at.$2),
    );
    for (final d in dives) {
      final site = sites[d.siteId]!;
      runTo((site.latitude, site.longitude));
      final until = _wallSeconds(d.start.add(d.plannedDuration));
      // On the mooring: a few metres of swing.
      while (clock + 60 < until) {
        clock += 60;
        points.add(
          GpsTrackPoint(
            timestamp: clock,
            latitude: site.latitude + (ctx.random.nextDouble() - 0.5) * 0.0004,
            longitude:
                site.longitude + (ctx.random.nextDouble() - 0.5) * 0.0004,
          ),
        );
      }
    }
    runTo(harbour);
    return points;
  }

  static double _metres((double, double) a, (double, double) b) {
    const r = 6371000.0;
    double rad(double d) => d * pi / 180;
    final h =
        pow(sin(rad(b.$1 - a.$1) / 2), 2) +
        cos(rad(a.$1)) * cos(rad(b.$1)) * pow(sin(rad(b.$2 - a.$2) / 2), 2);
    return 2 * r * asin(sqrt(h));
  }

  /// A local time as wall-clock-as-UTC epoch seconds, the tracks' convention.
  static int _wallSeconds(DateTime t) =>
      asWallClockUtc(t).millisecondsSinceEpoch ~/ 1000;
}
