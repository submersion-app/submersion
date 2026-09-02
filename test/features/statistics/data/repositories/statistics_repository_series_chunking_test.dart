import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

/// The two library-wide profile aggregates read the packed blobs a chunk of
/// dives at a time, so a large library never holds every blob at once. The
/// chunk boundary must not change the answer: a stream lives inside one
/// dive, so no chunk can split one, and the per-chunk totals combine.
void main() {
  late AppDatabase db;
  late StatisticsRepository repo;
  late ProfileSeriesRepository seriesRepository;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = StatisticsRepository();
    seriesRepository = ProfileSeriesRepository();
  });

  tearDown(() async {
    StatisticsRepository.seriesDiveChunkSize =
        StatisticsRepository.defaultSeriesDiveChunkSize;
    await tearDownTestDatabase();
  });

  Future<void> dive(String id) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// A descent to 30 m, a bottom phase, then an ascent: enough vertical
  /// movement for both rate figures and three depth buckets.
  Future<void> profile(String diveId, {bool isPrimary = true}) async {
    await seriesRepository.insertSeries(
      diveId: diveId,
      isPrimary: isPrimary,
      samples: [
        for (var t = 0; t <= 300; t += 10)
          ProfileSample(timestamp: t, depth: t / 10.0),
        for (var t = 310; t <= 900; t += 10)
          ProfileSample(timestamp: t, depth: 30.0),
        for (var t = 910; t <= 1500; t += 10)
          ProfileSample(timestamp: t, depth: 30.0 - (t - 900) / 20.0),
      ],
      now: now,
    );
  }

  Future<void> seedLibrary() async {
    for (final id in ['a', 'b', 'c', 'd', 'e']) {
      await dive(id);
      await profile(id);
    }
    // A demoted original on one dive: it must stay out of both aggregates
    // however the dives are chunked.
    await profile('a', isPrimary: false);
  }

  test('time at depth is the same however the dives are chunked', () async {
    await seedLibrary();

    StatisticsRepository.seriesDiveChunkSize =
        StatisticsRepository.defaultSeriesDiveChunkSize;
    final whole = await repo.getTimeAtDepthRanges();
    StatisticsRepository.seriesDiveChunkSize = 2;
    final chunked = await repo.getTimeAtDepthRanges();

    expect(whole, isNotEmpty);
    expect(chunked, whole);
  });

  test(
    'ascent and descent rates are the same however the dives are chunked',
    () async {
      await seedLibrary();

      StatisticsRepository.seriesDiveChunkSize =
          StatisticsRepository.defaultSeriesDiveChunkSize;
      final whole = await repo.getAscentDescentRates();
      StatisticsRepository.seriesDiveChunkSize = 1;
      final chunked = await repo.getAscentDescentRates();

      expect(whole.avgAscent, isNotNull);
      expect(whole.avgDescent, isNotNull);
      expect(chunked.avgAscent, closeTo(whole.avgAscent!, 1e-9));
      expect(chunked.avgDescent, closeTo(whole.avgDescent!, 1e-9));
    },
  );

  test('a library with no series still reports nothing', () async {
    await dive('empty');
    StatisticsRepository.seriesDiveChunkSize = 1;

    expect(await repo.getTimeAtDepthRanges(), isEmpty);
    final rates = await repo.getAscentDescentRates();
    expect(rates.avgAscent, isNull);
    expect(rates.avgDescent, isNull);
  });
}
