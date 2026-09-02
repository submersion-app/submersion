import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
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
}
