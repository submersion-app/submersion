import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// The PDF exporter needs depth profiles for many dives at once, but
/// `getAllDives` deliberately skips profile hydration for performance, so the
/// export path loads them itself.
///
/// It must not reach for `getDiveProfile`, nor for the `primaryOnly` series
/// read: both keep only `is_primary`, and per #623 `setPrimaryDataSource` can
/// leave a file-imported dive with no primary series at all. Those dives would
/// silently render a blank chart. The batch loader shares `_pointsForSeries`
/// with `getMergedProfile` instead, so the export and the on-screen chart
/// cannot drift apart.
void main() {
  late DiveRepository repository;
  late ProfileSeriesRepository seriesRepository;
  late AppDatabase db;

  const now = 1750000000000;

  Future<void> insertDive(String id) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: const Value(now),
            createdAt: const Value(now),
            updatedAt: const Value(now),
          ),
        );
  }

  var seriesCounter = 0;

  /// One series row carrying [samples], the way a download or an import
  /// writes it. Samples are `(timestamp, depth)` pairs.
  Future<void> insertSeries(
    String diveId,
    List<(int, double)> samples, {
    String? computerId,
    bool isPrimary = true,
  }) async {
    await seriesRepository.insertSeries(
      id: 'series-${seriesCounter++}',
      diveId: diveId,
      computerId: computerId,
      isPrimary: isPrimary,
      now: now,
      samples: [
        for (final (timestamp, depth) in samples)
          ProfileSample(timestamp: timestamp, depth: depth),
      ],
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    seriesRepository = ProfileSeriesRepository();
    seriesCounter = 0;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('returns profiles for several dives in one call', () async {
    await insertDive('diveA');
    await insertDive('diveB');
    await insertSeries('diveA', [(0, 0), (60, 12)]);
    await insertSeries('diveB', [(0, 0), (60, 30)]);

    final result = await repository.getMergedProfilesForDives([
      'diveA',
      'diveB',
    ]);

    expect(result['diveA'], hasLength(2));
    expect(result['diveB'], hasLength(2));
    expect(result['diveB']!.last.depth, 30);
  });

  test('returns samples for a dive whose series are all non-primary', () async {
    await insertDive('imported');
    await insertSeries('imported', [(0, 0), (60, 18)], isPrimary: false);

    final result = await repository.getMergedProfilesForDives(['imported']);

    expect(
      result['imported'],
      isNotEmpty,
      reason:
          'an isPrimary filter would silently drop file-imported dives (#623)',
    );
    expect(result['imported'], hasLength(2));
  });

  test('drops the originals a saved edit superseded', () async {
    await insertDive('edited');
    // The demoted original, as saveEditedProfile leaves it.
    await insertSeries('edited', [
      (0, 0),
      (60, 10),
      (120, 20),
    ], isPrimary: false);
    // The edited replacement, promoted: a trim that removed the tail.
    await insertSeries('edited', [(0, 0), (60, 10)]);

    final result = await repository.getMergedProfilesForDives(['edited']);

    expect(
      result['edited'],
      hasLength(2),
      reason: 'the demoted original must not be unioned back in',
    );
    expect(result['edited']!.map((p) => p.timestamp), [0, 60]);
  });

  test('omits dives that have no profile series', () async {
    await insertDive('bare');
    final result = await repository.getMergedProfilesForDives(['bare']);
    expect(result['bare'], anyOf(isNull, isEmpty));
  });

  test('handles more dives than one query chunk', () async {
    final ids = List.generate(120, (i) => 'dive$i');
    for (final id in ids) {
      await insertDive(id);
      await insertSeries(id, [(0, 0), (60, 15)]);
    }

    final result = await repository.getMergedProfilesForDives(ids);

    expect(result, hasLength(120));
    expect(result['dive119'], hasLength(2));
  });

  /// A dive with a promoted series alongside a demoted one that still names a
  /// computer is the only case where the primary `dive_data_sources` row
  /// decides which series survive. That read is the sole SQL the per-dive
  /// merge performs, so a bulk export of such dives is where an N+1 would
  /// show up.
  group('mixed-source dives', () {
    /// A demoted original from computer A plus a promoted series, which is
    /// what `needsPrimary` keys on.
    Future<void> insertMixedSource(String diveId, String computerId) async {
      await insertDive(diveId);
      // dive_data_sources.computer_id is a real FK, so the computer has to
      // exist before anything can point at it.
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(computerId),
              name: Value('Perdix $computerId'),
              createdAt: const Value(now),
              updatedAt: const Value(now),
            ),
          );
      await insertSeries(
        diveId,
        [(0, 0), (60, 10), (120, 20)],
        computerId: computerId,
        isPrimary: false,
      );
      await insertSeries(diveId, [(0, 0), (60, 10)]);
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: Value('src-$diveId'),
              diveId: Value(diveId),
              computerId: Value(computerId),
              isPrimary: const Value(true),
              importedAt: Value(DateTime.fromMillisecondsSinceEpoch(now)),
              createdAt: Value(DateTime.fromMillisecondsSinceEpoch(now)),
            ),
          );
    }

    test('reads dive_data_sources once, not once per dive', () async {
      // Statement logging rather than a stopwatch: the regression this guards
      // is the query count, which timing on an in-memory database would hide.
      await tearDownTestDatabase();
      db = AppDatabase(NativeDatabase.memory(logStatements: true));
      DatabaseService.instance.setTestDatabase(db);
      repository = DiveRepository();
      seriesRepository = ProfileSeriesRepository();

      final ids = List.generate(12, (i) => 'mixed$i');
      for (final id in ids) {
        await insertMixedSource(id, 'computer-$id');
      }

      final logged = <String>[];
      await runZoned(
        () => repository.getMergedProfilesForDives(ids),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logged.add(line),
        ),
      );

      final sourceReads = logged
          .where((line) => line.contains('dive_data_sources'))
          .length;
      expect(
        sourceReads,
        1,
        reason:
            'one batched read for all ${ids.length} dives, not one per dive',
      );
    });

    test('lands on the same points as the single-dive path', () async {
      await insertMixedSource('mixedA', 'computer-A');
      await insertMixedSource('mixedB', 'computer-B');

      final batched = await repository.getMergedProfilesForDives([
        'mixedA',
        'mixedB',
      ]);

      for (final id in ['mixedA', 'mixedB']) {
        final single = await repository.getMergedProfile(id);
        expect(
          batched[id]!.map((p) => (p.timestamp, p.depth)),
          single.map((p) => (p.timestamp, p.depth)),
          reason: 'the export and the on-screen chart must not drift apart',
        );
      }
    });

    test('still drops the superseded original', () async {
      await insertMixedSource('mixedC', 'computer-C');

      final result = await repository.getMergedProfilesForDives(['mixedC']);

      expect(result['mixedC'], hasLength(2));
      expect(result['mixedC']!.map((p) => p.timestamp), [0, 60]);
    });
  });
}
