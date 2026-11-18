import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/data/repositories/vertical_distance_cache.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance_timeline.dart';

import '../../../../helpers/test_database.dart';

/// A cache whose every read and write fails.
class _BrokenCache extends VerticalDistanceCacheRepository {
  _BrokenCache(LocalCacheDatabase db) : super(database: db);

  @override
  Future<Map<String, VerticalDistanceCacheEntry>> getEntries(
    Set<String> diveIds,
  ) async => throw StateError('cache read failed');

  @override
  Future<void> putAll(Map<String, VerticalDistanceCacheEntry> entries) async =>
      throw StateError('cache write failed');
}

/// A cache whose reads fail and whose writes are counted.
class _UnreadableCache extends VerticalDistanceCacheRepository {
  _UnreadableCache(LocalCacheDatabase db) : super(database: db);

  var writes = 0;

  @override
  Future<Map<String, VerticalDistanceCacheEntry>> getEntries(
    Set<String> diveIds,
  ) async => throw StateError('cache read failed');

  @override
  Future<void> putAll(Map<String, VerticalDistanceCacheEntry> entries) async {
    writes++;
  }
}

/// A cache that reads normally and whose writes fail and are counted.
class _UnwritableCache extends VerticalDistanceCacheRepository {
  _UnwritableCache(LocalCacheDatabase db) : super(database: db);

  var writes = 0;

  @override
  Future<void> putAll(Map<String, VerticalDistanceCacheEntry> entries) async {
    writes++;
    throw StateError('cache write failed');
  }
}

/// A cache that records each write.
class _CountingCache extends VerticalDistanceCacheRepository {
  _CountingCache(LocalCacheDatabase db) : super(database: db);

  final writes = <Map<String, VerticalDistanceCacheEntry>>[];

  @override
  Future<void> putAll(Map<String, VerticalDistanceCacheEntry> entries) async {
    writes.add(entries);
    await super.putAll(entries);
  }
}

/// Each dive's vertical distance from the repository, in dive order (issue
/// #4569).
void main() {
  late AppDatabase db;
  late LocalCacheDatabase local;
  late VerticalDistanceCacheRepository cache;
  late InsightsRepository repo;
  late ProfileSeriesRepository series;

  setUp(() async {
    db = await setUpTestDatabase();
    local = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    cache = VerticalDistanceCacheRepository(database: local);
    repo = InsightsRepository();
    series = ProfileSeriesRepository();
  });

  tearDown(() async {
    await local.close();
    await tearDownTestDatabase();
  });

  final day1 = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
  final day2 = DateTime.utc(2026, 1, 2).millisecondsSinceEpoch;
  final day3 = DateTime.utc(2026, 1, 3).millisecondsSinceEpoch;

  Future<void> diver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(day1),
          updatedAt: Value(day1),
        ),
      );

  Future<void> dive(
    String id, {
    required int at,
    double? maxDepth,
    String? diverId,
    bool isPlanned = false,
    bool excludedFromStats = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(at),
          maxDepth: Value(maxDepth),
          diverId: Value(diverId),
          isPlanned: Value(isPlanned),
          excludedFromStats: Value(excludedFromStats),
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );

  List<ProfileSample> samplesOf(List<(int, double)> s) => [
    for (final (t, d) in s) ProfileSample(timestamp: t, depth: d),
  ];

  Future<String> profile(
    String diveId,
    List<(int, double)> s, {
    bool isPrimary = true,
    String? computerId,
  }) => series.insertSeries(
    diveId: diveId,
    computerId: computerId,
    isPrimary: isPrimary,
    samples: samplesOf(s),
    now: day1,
  );

  const to20 = [(0, 0.0), (60, 20.0), (120, 0.0)];

  Future<VerticalDistanceTimeline> timeline({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    VerticalDistanceCacheRepository? using,
  }) => repo.getVerticalDistanceTimeline(
    diverId: diverId,
    filter: filter,
    cache: using ?? cache,
  );

  test('profile dives and max-depth dives, in dive order', () async {
    await dive('b', at: day2, maxDepth: 15);
    await dive('a', at: day1, maxDepth: 20);
    await profile('a', to20);

    final t = await timeline();

    expect(t.totalMeters, 35);
    expect(t.countedDives, 2);
    expect(t.estimatedDives, 1);
    expect(t.crossingAt(10)!.diveId, 'a');
    expect(t.crossingAt(10)!.estimated, isFalse);
    expect(t.crossingAt(10)!.startMillis, day1);
    expect(t.crossingAt(25)!.diveId, 'b');
    expect(t.crossingAt(25)!.estimated, isTrue);
  });

  test('a dive with neither a profile nor a max depth adds nothing', () async {
    await dive('a', at: day1);
    await dive('b', at: day2, maxDepth: 12);

    final t = await timeline();

    expect(t.totalMeters, 12);
    expect(t.countedDives, 1);
  });

  test('a profile never counts for less than the dive\'s max depth', () async {
    await dive('a', at: day1, maxDepth: 18);
    await profile('a', [(0, 0), (60, 12), (120, 0)]);

    final t = await timeline();

    expect(t.totalMeters, 18);
    expect(t.estimatedDives, 0);
  });

  test('a profile stored as two series rows counts once', () async {
    await dive('a', at: day1, maxDepth: 20);
    await profile('a', [(0, 0), (30, 10), (60, 20)], computerId: null);
    await profile('a', [(90, 10), (120, 0)], computerId: null);

    expect((await timeline()).totalMeters, 20);
  });

  test('a second read is served from the cache', () async {
    await dive('a', at: day1, maxDepth: 5);
    final id = await profile('a', to20);
    expect((await timeline()).totalMeters, 20);
    expect((await cache.getEntries({'a'}))['a']!.meters, 20);

    // Swap the packed samples for a 40 m dive of the same length without
    // touching the row's fingerprint: a cached read cannot see it.
    const codec = ProfileSeriesCodec();
    final deeper = codec.encode(samplesOf([(0, 0), (60, 40), (120, 0)])).bytes;
    await db.customUpdate(
      'UPDATE dive_profile_series SET samples = ? WHERE id = ?',
      variables: [Variable(deeper), Variable(id)],
      updates: {db.diveProfileSeries},
    );

    expect((await timeline()).totalMeters, 20);
  });

  test('a changed profile is worked out again', () async {
    await dive('a', at: day1, maxDepth: 5);
    final id = await profile('a', to20);
    expect((await timeline()).totalMeters, 20);

    const codec = ProfileSeriesCodec();
    final deeper = codec.encode(samplesOf([(0, 0), (60, 40), (120, 0)])).bytes;
    await db.customUpdate(
      'UPDATE dive_profile_series SET samples = ?, updated_at = ? '
      'WHERE id = ?',
      variables: [Variable(deeper), Variable(day2), Variable(id)],
      updates: {db.diveProfileSeries},
    );

    expect((await timeline()).totalMeters, 40);
  });

  test('a series that is not primary is ignored', () async {
    await dive('a', at: day1, maxDepth: 10);
    await profile('a', to20, isPrimary: false);

    final t = await timeline();

    expect(t.totalMeters, 10);
    expect(t.estimatedDives, 1);
  });

  test('the diver narrows the timeline', () async {
    await diver('x');
    await diver('y');
    await dive('a', at: day1, maxDepth: 10, diverId: 'x');
    await dive('b', at: day2, maxDepth: 30, diverId: 'y');

    expect((await timeline(diverId: 'x')).totalMeters, 10);
    expect((await timeline(diverId: 'y')).totalMeters, 30);
  });

  test('the Insights filter narrows the timeline', () async {
    await dive('a', at: day1, maxDepth: 10);
    await dive('b', at: day2, maxDepth: 20);
    await dive('c', at: day3, maxDepth: 40);

    final t = await timeline(
      filter: DiveFilterState(
        startDate: DateTime(2026, 1, 2),
        endDate: DateTime(2026, 1, 3),
      ),
    );

    expect(t.totalMeters, 60);
    expect(t.crossingAt(1)!.diveId, 'b');
  });

  test(
    'planned dives and dives excluded from statistics are left out',
    () async {
      await dive('a', at: day1, maxDepth: 10);
      await dive('plan', at: day2, maxDepth: 50, isPlanned: true);
      await dive('skip', at: day3, maxDepth: 70, excludedFromStats: true);

      expect((await timeline()).totalMeters, 10);
    },
  );

  test('dives starting together are ordered by id', () async {
    await dive('b', at: day1, maxDepth: 10);
    await dive('a', at: day1, maxDepth: 10);

    final t = await timeline();

    expect(t.crossingAt(5)!.diveId, 'a');
    expect(t.crossingAt(15)!.diveId, 'b');
  });

  test('a failing cache still gives the right timeline', () async {
    await dive('a', at: day1, maxDepth: 5);
    await profile('a', to20);
    await dive('b', at: day2, maxDepth: 15);

    final t = await timeline(using: _BrokenCache(local));

    expect(t.totalMeters, 35);
    expect(t.estimatedDives, 1);
  });

  test('a profile with no usable depth counts as estimated', () async {
    await dive('a', at: day1, maxDepth: 12);
    await profile('a', [(0, 0.0), (60, 0.0), (120, 0.0)]);

    final t = await timeline();

    expect(t.totalMeters, 12);
    expect(t.estimatedDives, 1);
  });

  test(
    'a profile that cannot be decoded is estimated, and not re-read',
    () async {
      await dive('a', at: day1, maxDepth: 15);
      final id = await profile('a', to20);
      await db.customUpdate(
        'UPDATE dive_profile_series SET samples = ? WHERE id = ?',
        variables: [
          Variable(Uint8List.fromList([1, 2, 3])),
          Variable(id),
        ],
        updates: {db.diveProfileSeries},
      );

      final t = await timeline();

      expect(t.totalMeters, 15);
      expect(t.estimatedDives, 1);
      // Cached as nothing measured, so the next read decodes nothing.
      expect((await cache.getEntries({'a'}))['a']!.meters, 0);
    },
  );

  test('the cache is written after each chunk, not only at the end', () async {
    final previous = InsightsRepository.seriesDiveChunkSize;
    InsightsRepository.seriesDiveChunkSize = 1;
    addTearDown(() => InsightsRepository.seriesDiveChunkSize = previous);
    for (final (id, at) in [('a', day1), ('b', day2), ('c', day3)]) {
      await dive(id, at: at);
      await profile(id, to20);
    }
    final counting = _CountingCache(local);

    await timeline(using: counting);

    expect(counting.writes, hasLength(3));
  });

  test('a cache that cannot be read is not written to either', () async {
    await dive('a', at: day1);
    await profile('a', to20);
    final broken = _UnreadableCache(local);

    expect((await timeline(using: broken)).totalMeters, 20);
    expect(broken.writes, 0);
  });

  test('after a failed write the cache is not written again', () async {
    final previous = InsightsRepository.seriesDiveChunkSize;
    InsightsRepository.seriesDiveChunkSize = 1;
    addTearDown(() => InsightsRepository.seriesDiveChunkSize = previous);
    for (final (id, at) in [('a', day1), ('b', day2), ('c', day3)]) {
      await dive(id, at: at);
      await profile(id, to20);
    }
    final unwritable = _UnwritableCache(local);

    expect((await timeline(using: unwritable)).totalMeters, 60);
    expect(unwritable.writes, 1);
  });

  test('no dives give the empty timeline', () async {
    expect((await timeline()).isEmpty, isTrue);
  });

  group('max depths added up', () {
    Future<VerticalDistanceTimeline> maxDepths({
      String? diverId,
      DiveFilterState filter = const DiveFilterState(),
    }) => repo.getMaxDepthTimeline(diverId: diverId, filter: filter);

    test('each dive counts its max depth, never its profile', () async {
      await dive('a', at: day1, maxDepth: 20);
      // The profile goes 20 m, back to 10 m and down to 20 m again: 30 m
      // travelled, but only its 20 m max depth counts here.
      await profile('a', [(0, 0), (60, 20), (120, 10), (180, 20), (240, 0)]);
      await dive('b', at: day2, maxDepth: 15);

      final t = await maxDepths();

      expect(t.totalMeters, 35);
      expect(t.countedDives, 2);
      expect(t.estimatedDives, 0);
      expect(t.crossingAt(10)!.diveId, 'a');
      expect(t.crossingAt(25)!.diveId, 'b');
      expect(t.crossingAt(25)!.startMillis, day2);
    });

    test('a dive with no max depth adds nothing', () async {
      await dive('a', at: day1);
      await profile('a', to20);
      await dive('b', at: day2, maxDepth: 12);

      final t = await maxDepths();

      expect(t.totalMeters, 12);
      expect(t.countedDives, 1);
    });

    test('the diver and the Insights scope narrow it', () async {
      await diver('x');
      await diver('y');
      await dive('a', at: day1, maxDepth: 10, diverId: 'x');
      await dive('b', at: day2, maxDepth: 30, diverId: 'y');
      await dive('plan', at: day2, maxDepth: 50, diverId: 'x', isPlanned: true);
      await dive(
        'skip',
        at: day3,
        maxDepth: 70,
        diverId: 'x',
        excludedFromStats: true,
      );
      await dive('c', at: day3, maxDepth: 40, diverId: 'x');

      expect((await maxDepths(diverId: 'x')).totalMeters, 50);
      expect((await maxDepths(diverId: 'y')).totalMeters, 30);
      final filtered = await maxDepths(
        diverId: 'x',
        filter: DiveFilterState(startDate: DateTime(2026, 1, 3)),
      );
      expect(filtered.totalMeters, 40);
    });

    test('no dives give the empty timeline', () async {
      expect((await maxDepths()).isEmpty, isTrue);
    });
  });
}
