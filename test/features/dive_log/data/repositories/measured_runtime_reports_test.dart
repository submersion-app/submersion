import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveTanksCompanion;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/role_consumption.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

/// Every report of how long a diver was in the water reads the measured
/// runtime, so a hand-logged dive with only a bottom time adds nothing to it
/// (issue #3304).
///
/// timed:   60 min runtime, 50 min bottom time.
/// stamped: 40 min between entry and exit, 30 min bottom time, no runtime.
/// sampled: a 20 min profile, 15 min bottom time, no runtime.
/// logged:  90 min bottom time and nothing else: the longest figure of the
///          four, so any report still reading it names the wrong dive.
const _measuredMinutes = 60 + 40 + 20;

const _site = DiveSite(id: 'site', name: 'House Reef');

void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late InsightsRepository insights;
  late String tripId;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    insights = InsightsRepository();
    await SiteRepository().createSite(_site);
    final now = DateTime.utc(2026, 3, 1);
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Red Sea',
        startDate: now,
        endDate: DateTime.utc(2026, 3, 8),
        createdAt: now,
        updatedAt: now,
      ),
    );
    tripId = trip.id;
    domain.Dive dive(
      String id,
      int day, {
      Duration? runtime,
      DateTime? entry,
      DateTime? exit,
      List<domain.DiveProfilePoint> profile = const [],
      required Duration bottomTime,
    }) => domain.Dive(
      id: id,
      dateTime: DateTime.utc(2026, 3, day, 10),
      runtime: runtime,
      entryTime: entry,
      exitTime: exit,
      profile: profile,
      bottomTime: bottomTime,
      maxDepth: 18,
      avgDepth: 15,
      site: _site,
      tripId: tripId,
      diveTypeIds: const ['night'],
    );

    await dives.createDive(
      dive(
        'timed',
        1,
        runtime: const Duration(minutes: 60),
        bottomTime: const Duration(minutes: 50),
      ),
    );
    await dives.createDive(
      dive(
        'stamped',
        2,
        entry: DateTime.utc(2026, 3, 2, 10),
        exit: DateTime.utc(2026, 3, 2, 10, 40),
        bottomTime: const Duration(minutes: 30),
      ),
    );
    await dives.createDive(
      dive(
        'sampled',
        3,
        profile: [
          for (var t = 0; t <= 1200; t += 60)
            domain.DiveProfilePoint(
              timestamp: t,
              depth: t == 0 || t == 1200 ? 0 : 18,
            ),
        ],
        bottomTime: const Duration(minutes: 15),
      ),
    );
    await dives.createDive(
      dive('logged', 4, bottomTime: const Duration(minutes: 90)),
    );
    for (final id in ['timed', 'stamped', 'sampled', 'logged']) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value('tank-$id'),
              diveId: Value(id),
              startPressure: const Value(200),
              endPressure: const Value(140),
              volume: const Value(12),
              tankRole: const Value('backGas'),
              o2Percent: const Value(21),
              hePercent: const Value(0),
              tankOrder: const Value(0),
            ),
          );
    }
  });
  tearDown(() async => tearDownTestDatabase());

  test('the hand-logged dive really has no measured runtime', () async {
    final row = await (db.select(
      db.dives,
    )..where((d) => d.id.equals('logged'))).getSingle();
    expect(row.runtime, isNull);
    expect(row.exitTime, isNull);
    expect(row.bottomTime, 90 * 60);
  });

  group('totals', () {
    test('career hours count only measured runtimes', () async {
      final stats = await dives.getStatistics();
      expect(stats.totalDives, 4);
      expect(stats.totalTimeSeconds, _measuredMinutes * 60);
    });

    test('the depth distribution sums measured runtimes', () async {
      final stats = await dives.getStatistics();
      final bucket = stats.depthDistribution.firstWhere((b) => b.count > 0);
      expect(bucket.count, 4);
      expect(bucket.totalDurationSeconds, _measuredMinutes * 60);
    });

    test('a year counts only measured runtimes', () async {
      final year = await insights.getYearStats(2026);
      expect(year.diveCount, 4);
      expect(year.totalSeconds, _measuredMinutes * 60);
    });

    test('the dive type distribution sums measured runtimes', () async {
      final segments = await insights.getDiveTypeDistribution();
      final night = segments.firstWhere((s) => s.label == 'night');
      expect(night.count, 4);
      expect(night.totalDurationSeconds, _measuredMinutes * 60);
    });

    test('a trip counts only measured runtimes', () async {
      final trip = await TripRepository().getTripWithStats(tripId);
      expect(trip.diveCount, 4);
      expect(trip.totalRuntime, _measuredMinutes * 60);
    });

    test('the trip list counts only measured runtimes', () async {
      final trips = await TripRepository().getAllTripsWithStats();
      final trip = trips.singleWhere((t) => t.trip.id == tripId);
      expect(trip.totalRuntime, _measuredMinutes * 60);
    });
  });

  group('records', () {
    test('a bottom time cannot be the longest dive', () async {
      final records = await dives.getRecords();
      expect(records.longestDive?.diveId, 'timed');
      expect(records.longestDive?.runtime, const Duration(minutes: 60));
    });

    test('the personal record agrees with the Records page', () async {
      final ids = await dives.getPersonalRecordIds();
      expect(ids.longestId, 'timed');
    });

    test('a longest dive with no runtime column reports what it measured, '
        'not its bottom time', () async {
      await db.customStatement("DELETE FROM dives WHERE id = 'timed'");
      final records = await dives.getRecords();
      expect(records.longestDive?.diveId, 'stamped');
      expect(records.longestDive?.runtime, const Duration(minutes: 40));
    });

    test('no measured dive means no longest dive', () async {
      await db.customStatement("DELETE FROM dives WHERE id != 'logged'");
      final records = await dives.getRecords();
      expect(records.longestDive, isNull);
      final ids = await dives.getPersonalRecordIds();
      expect(ids.longestId, isNull);
    });

    test('a site reports its measured dives', () async {
      final site = await insights.getSiteDiveStatistics(siteId: 'site');
      expect(site.diveCount, 4);
      expect(site.longestDiveSeconds, 60 * 60);
      expect(site.longestDiveId, 'timed');
      // The average of the three measured dives, not of all four.
      expect(site.averageDurationSeconds, _measuredMinutes * 60 / 3);
    });

    test('the site list reports measured dives', () async {
      final aggregates = await SiteRepository().getDiveAggregatesBySite();
      final site = aggregates['site']!;
      expect(site.longestDiveSeconds, 60 * 60);
      expect(site.averageDurationSeconds, _measuredMinutes * 60 / 3);
    });
  });

  group('dive summaries', () {
    test('carry what a dive measured, and no bottom time', () async {
      final summaries = await dives.getDiveSummaries(limit: 10);
      final byId = {for (final s in summaries) s.id: s.runtime};
      expect(byId['timed'], const Duration(minutes: 60));
      expect(byId['stamped'], const Duration(minutes: 40));
      expect(byId['sampled'], const Duration(minutes: 20));
      expect(byId['logged'], isNull);
    });
  });

  group('SAC and RMV', () {
    // 60 bar over the measured runtime at 15 m average depth.
    const stamped = 60 / 40 / 2.5;

    test('the trend charts leave a bottom-time dive off', () async {
      final pressure = await insights.getSacPressurePerDive();
      expect(pressure, hasLength(3));
      final volume = await insights.getSacVolumePerDive();
      expect(volume, hasLength(3));
    });

    test('a dive measured by its times divides by that span', () async {
      final points = await insights.getSacPressurePerDive();
      final byDay = {for (final p in points) p.date.day: p.value};
      expect(byDay[2], closeTo(stamped, 0.05));
    });

    test('the best and worst dive are measured dives', () async {
      final pressure = await insights.getSacPressureRecords();
      expect(pressure.best?.id, 'timed');
      expect(pressure.worst?.id, 'sampled');
      final volume = await insights.getSacVolumeRecords();
      expect(volume.best?.id, 'timed');
      expect(volume.worst?.id, 'sampled');
    });

    test('consumption by cylinder role ignores a bottom-time dive', () async {
      final trend = await insights.getRoleConsumptionPerDive();
      final volume = await insights.getSacVolumePerDive();
      expect(
        trend.rmv[ConsumptionRoleGroup.bottomGas]!.map((p) => p.diveId),
        volume.map((p) => p.diveId),
      );
      expect(trend.sac[ConsumptionRoleGroup.bottomGas], hasLength(3));
    });
  });
}
