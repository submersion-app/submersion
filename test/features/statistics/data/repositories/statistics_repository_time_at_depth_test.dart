import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late StatisticsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = StatisticsRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> diver(String id) async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> dive(String id, {String? diverId}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            diverId: Value(diverId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> computer(String id) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// Inserts profile samples as (timestamp seconds, depth meters) pairs.
  Future<void> profile(
    String diveId,
    List<(int, double)> samples, {
    bool isPrimary = true,
    String? computerId,
    String idPrefix = 'row',
  }) async {
    await db.batch((batch) {
      for (final (index, sample) in samples.indexed) {
        batch.insert(
          db.diveProfiles,
          DiveProfilesCompanion(
            id: Value('$diveId-${computerId ?? 'dc'}-$idPrefix-$index'),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            timestamp: Value(sample.$1),
            depth: Value(sample.$2),
          ),
        );
      }
    });
  }

  /// Holds [depth] from [from] to [to] seconds, sampled every [every] seconds.
  ///
  /// The closing sample lands exactly on [to], so the samples span `to - from`
  /// seconds of elapsed time regardless of the interval.
  List<(int, double)> level(
    double depth, {
    required int from,
    required int to,
    required int every,
  }) => [for (var t = from; t <= to; t += every) (t, depth)];

  int? minutesAt(
    List<({int lowerDepth, int? upperDepth, int minutes})> ranges,
    int lowerDepth,
  ) {
    for (final range in ranges) {
      if (range.lowerDepth == lowerDepth) return range.minutes;
    }
    return null;
  }

  test('reports elapsed minutes, not one minute per sixty samples', () async {
    await dive('a');
    // 30 minutes held at 5 m, sampled every 4 s: 451 rows. Counting rows and
    // dividing by 60 reports 8 minutes for the same half hour.
    await profile('a', level(5.0, from: 0, to: 1800, every: 4));

    final ranges = await repo.getTimeAtDepthRanges();

    expect(minutesAt(ranges, 0), 30);
  });

  test('is independent of the recording interval', () async {
    await dive('fast');
    await profile('fast', level(5.0, from: 0, to: 1800, every: 1));
    await dive('slow');
    await profile('slow', level(25.0, from: 0, to: 1800, every: 20));

    final ranges = await repo.getTimeAtDepthRanges();

    // The same half hour underwater, recorded twenty times more sparsely.
    expect(minutesAt(ranges, 0), 30);
    expect(minutesAt(ranges, 20), 30);
  });

  test('attributes each interval to the depth it started at', () async {
    await dive('a');
    await profile('a', [
      ...level(5.0, from: 0, to: 300, every: 5),
      ...level(15.0, from: 305, to: 900, every: 5),
      ...level(45.0, from: 905, to: 1200, every: 5),
    ]);

    final ranges = await repo.getTimeAtDepthRanges();

    // Each leg carries the 5 s step that leaves it into its own bucket, so the
    // three legs are 305 s, 600 s and 295 s: 5, 10 and 5 minutes.
    expect(minutesAt(ranges, 0), 5);
    expect(minutesAt(ranges, 10), 10);
    expect(minutesAt(ranges, 40), 5);
    expect(minutesAt(ranges, 20), isNull);
  });

  test('leaves the deepest bucket open-ended', () async {
    await dive('a');
    await profile('a', level(60.0, from: 0, to: 600, every: 10));

    final ranges = await repo.getTimeAtDepthRanges();

    expect(ranges.single.lowerDepth, 40);
    expect(ranges.single.upperDepth, isNull);
  });

  test('counts only the primary profile of a multi-computer dive', () async {
    await dive('a');
    await computer('dc-primary');
    await computer('dc-secondary');
    await profile(
      'a',
      level(5.0, from: 0, to: 1800, every: 4),
      computerId: 'dc-primary',
    );
    // The same dive as logged by a second, demoted computer. Counting both
    // sample streams doubles every bucket.
    await profile(
      'a',
      level(5.0, from: 0, to: 1800, every: 2),
      isPrimary: false,
      computerId: 'dc-secondary',
    );

    final ranges = await repo.getTimeAtDepthRanges();

    expect(minutesAt(ranges, 0), 30);
  });

  test('is unaffected by exact duplicate profile rows', () async {
    await dive('a');
    // A repeated import stores every sample twice. Row counts double; the
    // elapsed time between distinct timestamps does not.
    await profile('a', level(5.0, from: 0, to: 1800, every: 4));
    await profile(
      'a',
      level(5.0, from: 0, to: 1800, every: 4),
      idPrefix: 'reimport',
    );

    final ranges = await repo.getTimeAtDepthRanges();

    expect(minutesAt(ranges, 0), 30);
  });

  test('clamps a recording gap instead of crediting it to a bucket', () async {
    await dive('a');
    // Fifteen minutes recorded, forty minutes of silence, fifteen more. The
    // pause must not read as forty minutes spent at 5 m.
    await profile('a', [
      ...level(5.0, from: 0, to: 900, every: 2),
      ...level(5.0, from: 3300, to: 4200, every: 2),
    ]);

    final ranges = await repo.getTimeAtDepthRanges();

    expect(minutesAt(ranges, 0), closeTo(30, 1));
  });

  test('applies the statistics dive filter', () async {
    await db
        .into(db.tags)
        .insert(
          TagsCompanion(
            id: const Value('deep'),
            name: const Value('deep'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await dive('a');
    await profile('a', level(25.0, from: 0, to: 1800, every: 4));
    await dive('b');
    await profile('b', level(25.0, from: 0, to: 1800, every: 4));
    await db
        .into(db.diveTags)
        .insert(
          DiveTagsCompanion(
            id: const Value('a-deep'),
            diveId: const Value('a'),
            tagId: const Value('deep'),
            createdAt: Value(now),
          ),
        );

    final unfiltered = await repo.getTimeAtDepthRanges();
    expect(minutesAt(unfiltered, 20), 60);

    final filtered = await repo.getTimeAtDepthRanges(
      filter: const DiveFilterState(tagIds: ['deep']),
    );
    expect(minutesAt(filtered, 20), 30);
  });

  test('scopes the totals to the requested diver', () async {
    await diver('diver-1');
    await diver('diver-2');
    await dive('a', diverId: 'diver-1');
    await profile('a', level(5.0, from: 0, to: 1800, every: 4));
    await dive('b', diverId: 'diver-2');
    await profile('b', level(5.0, from: 0, to: 600, every: 4));

    expect(
      minutesAt(await repo.getTimeAtDepthRanges(diverId: 'diver-1'), 0),
      30,
    );
    expect(
      minutesAt(await repo.getTimeAtDepthRanges(diverId: 'diver-2'), 0),
      10,
    );
  });

  test('neither loses nor invents time when timestamps tie', () async {
    await dive('a');
    // Two samples share t=300 s at depths that fall in different buckets. The
    // window orders by (timestamp, id), so the tie is broken by row id: the
    // 11 m row sorts last and carries the interval that leaves the tie.
    await profile('a', [
      (0, 5.0),
      (300, 9.0),
      (300, 11.0),
      (600, 5.0),
      (900, 5.0),
    ]);

    final ranges = await repo.getTimeAtDepthRanges();

    // 900 s elapsed from the first sample to the last, split 600/300.
    expect(ranges.fold<int>(0, (sum, r) => sum + r.minutes), 15);
    expect(minutesAt(ranges, 0), 10);
    expect(minutesAt(ranges, 10), 5);
  });

  test('returns nothing for a single-sample profile', () async {
    await dive('a');
    await profile('a', [(0, 12.0)]);

    expect(await repo.getTimeAtDepthRanges(), isEmpty);
  });
}
