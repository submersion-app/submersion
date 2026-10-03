import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The recent-queries providers against a real cache database: the
/// recorder Ask writes through, and the list PR 4 shows.
void main() {
  late LocalCacheDatabase cacheDb;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
  });
  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  Future<ProviderContainer> container() async {
    final overrides = await getBaseOverrides();
    final c = ProviderContainer(
      overrides: [
        ...overrides,
        localeProvider.overrideWithValue('en'),
        exploreNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
      ].cast(),
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the recorder writes a recent query the list provider reads', () async {
    final c = await container();
    await c.read(recentQueryRecorderProvider)(
      'turtles in bonaire',
      'en',
      const ParsedQuery(subject: ParsedSubject.dives),
      '',
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
          const ParsedQuery(subject: ParsedSubject.dives),
          diverId: '',
        );
    expect(await c.read(recentQueriesProvider.future), isEmpty);
  });

  test('recent queries are scoped to the active diver', () async {
    final overrides = await getBaseOverrides();
    final c = ProviderContainer(
      overrides: [
        ...overrides,
        localeProvider.overrideWithValue('en'),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'ana'),
      ].cast(),
    );
    addTearDown(c.dispose);
    await c
        .read(recentQueryRepositoryProvider)
        .record(
          'wrecks with Bob',
          'en',
          const ParsedQuery(subject: ParsedSubject.dives),
          diverId: 'bob',
        );
    await c.read(recentQueryRecorderProvider)(
      'turtles with Ana',
      'en',
      const ParsedQuery(subject: ParsedSubject.dives),
      'ana',
    );
    final recent = await c.read(recentQueriesProvider.future);
    expect(recent.map((r) => r.sentence), ['turtles with Ana']);
  });
}
