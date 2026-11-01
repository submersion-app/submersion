@Tags(['performance'])
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart' hide Tags;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';

import '../helpers/drift_statement_log.dart';

/// Issue #3831: what a trip screen waits for, by the size of the trip.
///
/// Every dive is a dense two-computer recording: an hour at one sample a
/// second from each computer, and two cylinders' pressure series. "Before" is
/// the old body of `divesForTripProvider` (`getDivesByIds` plus `withBuddies`)
/// put back through an override; "after" is the provider as it stands. Both
/// run the real providers against a database file.
///
/// Statements come from a separate logging pass, since logging every
/// statement would swamp the timings. `flutter test --run-skipped
/// test/performance/trip_dives_benchmark_test.dart`.
void main() {
  const tripSizes = [10, 50, 200];
  const runsPerPath = 5;
  const tripId = 'trip';

  test('trip screens wait less on a large trip', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final work = Directory.systemTemp.createTempSync('trip-dives-bench');
    addTearDown(() {
      if (work.existsSync()) work.deleteSync(recursive: true);
    });

    var isOpen = false;
    AppDatabase open(String path, {bool log = false}) {
      final db = AppDatabase(
        NativeDatabase(
          File(path),
          logStatements: log,
          setup: registerAppSqlFunctions,
        ),
      );
      DatabaseService.instance.setTestDatabase(db);
      isOpen = true;
      return db;
    }

    Future<void> close() async {
      if (!isOpen) return;
      isOpen = false;
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();
    }

    // A failure partway through still puts the database back.
    addTearDown(close);

    // The old body of divesForTripProvider.
    Future<List<domain.Dive>> legacyRead() async {
      final ids = await TripRepository().getDiveIdsForTrip(tripId);
      return BuddyRepository().withBuddies(
        await DiveRepository().getDivesByIds(ids),
      );
    }

    ProviderContainer container({required bool legacy}) => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (legacy)
          divesForTripProvider(tripId).overrideWith((ref) => legacyRead()),
      ],
    );

    Future<int> timeOf(Future<void> Function() read) async {
      final clock = Stopwatch()..start();
      await read();
      return clock.elapsedMicroseconds;
    }

    int median(List<int> values) =>
        (List.of(values)..sort())[values.length ~/ 2];

    final rows = <String>[];
    for (final size in tripSizes) {
      final path = p.join(work.path, 'trip-$size.db');
      await _createTrip(open(path), tripId, size);

      // Runs alternate, so neither path owns a warm page cache.
      final dives = {true: <int>[], false: <int>[]};
      final overview = {true: <int>[], false: <int>[]};
      for (var run = 0; run < runsPerPath * 2; run++) {
        final legacy = run.isEven;
        final forDives = container(legacy: legacy);
        dives[legacy]!.add(
          await timeOf(
            () => forDives.read(divesForTripProvider(tripId).future),
          ),
        );
        forDives.dispose();
        final forStory = container(legacy: legacy);
        overview[legacy]!.add(
          await timeOf(() => forStory.read(tripStoryProvider(tripId).future)),
        );
        forStory.dispose();
      }

      final blobBytes = await _seriesBytes();
      final heldPoints = (await legacyRead()).fold<int>(
        0,
        (sum, dive) => sum + dive.profile.length,
      );
      final leanPoints = (await DiveRepository().getDivesByIdsWithoutSamples(
        await TripRepository().getDiveIdsForTrip(tripId),
      )).fold<int>(0, (sum, dive) => sum + dive.profile.length);
      await close();

      open(path, log: true);
      final ids = await TripRepository().getDiveIdsForTrip(tripId);
      final legacyStatements = await statementsOf(legacyRead);
      final leanStatements = await statementsOf(
        () => DiveRepository().getDivesByIdsWithoutSamples(ids),
      );
      final leanBlobReads = leanStatements.where(readsSeriesBlob).length;
      await close();

      expect(leanBlobReads, 0, reason: 'decoded a series on a $size-dive trip');
      expect(leanPoints, 0);
      expect(leanStatements.length, lessThan(legacyStatements.length));
      expect(median(dives[false]!), lessThan(median(dives[true]!)));

      String ms(int micros) => (micros / 1000).toStringAsFixed(1);
      rows.add(
        '| $size '
        '| ${legacyStatements.length} | ${leanStatements.length} '
        '| ${(blobBytes / 1024).toStringAsFixed(0)} KiB | 0 '
        '| $heldPoints | $leanPoints '
        '| ${ms(median(dives[true]!))} | ${ms(median(dives[false]!))} '
        '| ${ms(median(overview[true]!))} '
        '| ${ms(median(overview[false]!))} |',
      );
    }

    stdout.writeln(
      '| Dives | Statements before | after | Series read before | after '
      '| Points held before | after | Dives tab ms before | after '
      '| Overview ms before | after |\n'
      '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n'
      '${rows.join('\n')}',
    );
  });
}

/// Blob bytes across every series of every dive: what a detail read of the
/// whole trip pulls out of the database.
Future<int> _seriesBytes() async {
  final row = await DatabaseService.instance.database
      .customSelect(
        'SELECT (SELECT COALESCE(SUM(LENGTH(samples)), 0) '
        'FROM dive_profile_series) + '
        '(SELECT COALESCE(SUM(LENGTH(samples)), 0) '
        'FROM tank_pressure_series) AS bytes',
      )
      .getSingle();
  return row.read<int>('bytes');
}

/// One hour at one sample a second, a square profile with some texture, the
/// shape a modern computer records.
List<ProfileSample> _hourOfSamples(int seed) {
  const seconds = 3600;
  return [
    for (var t = 0; t < seconds; t++)
      ProfileSample(
        timestamp: t,
        depth:
            math.min(30, math.min(t, seconds - t) / 6) +
            math.sin((t + seed) / 17) * 0.4,
        temperature: 24 + math.sin(t / 311),
        ndl: (seconds - t) ~/ 2,
        cns: t / 180,
        ceiling: t % 5 == 0 ? 3 : 0,
      ),
  ];
}

Future<void> _createTrip(AppDatabase db, String tripId, int diveCount) async {
  final repository = DiveRepository();
  final series = ProfileSeriesRepository();
  final pressures = TankPressureRepository();
  final start = DateTime.utc(2026, 3, 1, 8);
  const now = 1700000000000;

  await db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          id: tripId,
          name: 'Bench',
          startDate: start.millisecondsSinceEpoch,
          endDate: start
              .add(Duration(days: diveCount ~/ 4 + 1))
              .millisecondsSinceEpoch,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: 'site',
          name: 'Salt Pier',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: 'buddy',
          name: 'Sam',
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (final computer in ['perdix', 'teric']) {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: computer,
            name: computer,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  // The series differ only by seed, so a shared set keeps the fixture quick
  // to build without letting the codec fold every dive into one blob's worth.
  final samples = [for (var seed = 0; seed < 4; seed++) _hourOfSamples(seed)];

  for (var i = 0; i < diveCount; i++) {
    final id = 'dive-$i';
    final entry = start.add(Duration(hours: i * 6));
    await repository.createDive(
      domain.Dive(
        id: id,
        diveNumber: i + 1,
        tripId: tripId,
        dateTime: entry,
        entryTime: entry,
        exitTime: entry.add(const Duration(hours: 1)),
        runtime: const Duration(hours: 1),
        bottomTime: const Duration(minutes: 50),
        maxDepth: 30,
        avgDepth: 18,
        waterTemp: 24,
        tanks: [
          domain.DiveTank(
            id: '$id-back',
            volume: 12,
            startPressure: 210,
            endPressure: 60,
            gasMix: const domain.GasMix(),
          ),
          domain.DiveTank(
            id: '$id-stage',
            volume: 7,
            startPressure: 200,
            endPressure: 120,
            gasMix: const domain.GasMix(o2: 50),
          ),
        ],
      ),
    );
    await db.customStatement('UPDATE dives SET site_id = ? WHERE id = ?', [
      'site',
      id,
    ]);
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: '$id-buddy',
            diveId: id,
            buddyId: 'buddy',
            role: const Value('buddy'),
            createdAt: now,
          ),
        );

    for (final (slot, computer) in ['perdix', 'teric'].indexed) {
      final importedAt = DateTime.utc(2026, 3, 2).add(Duration(minutes: slot));
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: '$id-$computer',
              diveId: id,
              computerId: Value(computer),
              isPrimary: Value(slot == 0),
              importedAt: importedAt,
              createdAt: importedAt,
            ),
          );
      await series.insertSeries(
        diveId: id,
        computerId: computer,
        sourceId: '$id-$computer',
        isPrimary: slot == 0,
        samples: samples[(i + slot) % samples.length],
      );
    }
    await pressures.insertTankPressures(id, {
      '$id-back': _pressures(210, 60),
      '$id-stage': _pressures(200, 120),
    }, sourceId: '$id-perdix');
  }
}

List<({int timestamp, double pressure})> _pressures(double from, double to) => [
  for (var t = 0; t < 3600; t += 2)
    (timestamp: t, pressure: from - (from - to) * t / 3600),
];
