import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The result, count and chart providers against a real database, so the
/// query bodies the widget tests stub out are actually executed.
void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
  });
  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value('Site $id'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> insertDive(String id, {double? depth, String? siteId}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
          maxDepth: Value(depth),
          waterTemp: const Value(18),
          bottomTime: const Value(2400),
          siteId: Value(siteId),
        ),
      );

  Future<ProviderContainer> container() async {
    final overrides = await getBaseOverrides();
    final c = ProviderContainer(
      overrides: [
        ...overrides,
        localeProvider.overrideWithValue('en'),
        nameIndexProvider.overrideWith((ref) async => NameIndex.empty),
      ].cast(),
    );
    addTearDown(c.dispose);
    return c;
  }

  test('results and count are empty until a filter is active', () async {
    await insertDive('a', depth: 30);
    final c = await container();
    expect(await c.read(exploreResultsProvider.future), isEmpty);
    expect(await c.read(exploreCountProvider.future), 0);
  });

  test('results and count read the published filter', () async {
    await insertDive('deep', depth: 30);
    await insertDive('shallow', depth: 5);
    final c = await container();
    c.read(exploreFilterProvider.notifier).state = const DiveFilterState(
      minDepth: 20,
    );
    final results = await c.read(exploreResultsProvider.future);
    expect(results.map((s) => s.id), ['deep']);
    expect(await c.read(exploreCountProvider.future), 1);
  });

  test('every chart kind runs its query under the filter', () async {
    await insertSite('s1');
    await insertSite('s2');
    await insertDive('a', depth: 30, siteId: 's1');
    await insertDive('b', depth: 25, siteId: 's2');
    await insertDive('shallow', depth: 4, siteId: 's1');
    final c = await container();
    c.read(exploreFilterProvider.notifier).state = const DiveFilterState(
      minDepth: 20,
    );

    for (final kind in [
      ChartKind.divesOverTime,
      ChartKind.depthTrend,
      ChartKind.waterTempTrend,
      ChartKind.bottomTimeTrend,
    ]) {
      final data = await c.read(
        exploreChartDataProvider(ChartRequest(kind)).future,
      );
      expect(data.points, isNotEmpty, reason: kind.name);
      expect(data.bars, isEmpty, reason: kind.name);
    }

    final sites = await c.read(
      exploreChartDataProvider(
        const ChartRequest(
          ChartKind.entityCounts,
          entityKind: MentionKind.place,
        ),
      ).future,
    );
    expect(sites.bars.map((b) => b.label), ['Site s1', 'Site s2']);
    expect(sites.bars.every((b) => b.count == 1), isTrue);
  });

  test('every entity-count kind resolves to a ranking query', () async {
    await insertDive('a', depth: 30);
    final c = await container();
    c.read(exploreFilterProvider.notifier).state = const DiveFilterState(
      minDepth: 20,
    );
    for (final kind in [
      MentionKind.species,
      MentionKind.buddy,
      MentionKind.center,
      MentionKind.gear,
    ]) {
      final data = await c.read(
        exploreChartDataProvider(
          ChartRequest(ChartKind.entityCounts, entityKind: kind),
        ).future,
      );
      expect(data.points, isEmpty, reason: kind.name);
    }
  });

  test('an inactive filter short-circuits every chart', () async {
    await insertDive('a', depth: 30);
    final c = await container();
    final data = await c.read(
      exploreChartDataProvider(const ChartRequest(ChartKind.depthTrend)).future,
    );
    expect(data.points, isEmpty);
    expect(data.bars, isEmpty);
  });

  test('the recorder writes a recent query the list provider reads', () async {
    final c = await container();
    await c.read(recentQueryRecorderProvider)(
      'turtles in bonaire',
      'en',
      const ParsedQuery(subject: QuerySubject.dives),
    );
    final recent = await c.read(recentQueriesProvider.future);
    expect(recent.map((r) => r.sentence), ['turtles in bonaire']);
  });

  test('recent queries are scoped to the active locale', () async {
    final c = await container();
    await c
        .read(recentQueryRepositoryProvider)
        .record(
          'tortues',
          'fr',
          const ParsedQuery(subject: QuerySubject.dives),
        );
    expect(await c.read(recentQueriesProvider.future), isEmpty);
  });
}
