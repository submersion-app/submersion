import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/global_search/data/global_search_repository.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';

import '../../../helpers/shared_items_fixture.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['me', 'other']);
    await seedSite(db, 's1', owner: 'me', name: 'Salt Pier');
    container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
        queryUnitPrefsProvider.overrideWithValue(kMetricPrefs),
        queryIdSetRunnerProvider.overrideWithValue(QueryIdSetRunner(db)),
        globalSearchRepositoryProvider.overrideWithValue(
          GlobalSearchRepository(db),
        ),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  Future<List<GlobalSearchSection>> search(String text) async {
    final provider = globalSearchProvider(text);
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    return container.read(provider.future);
  }

  test('leaves out the record types with no match', () async {
    final sections = await search('salt');
    expect(sections.map((s) => s.kind), [GlobalSearchKind.sites]);
    expect(sections.single.total, 1);
  });

  test('nothing matching is an empty answer', () async {
    expect(await search('zzz'), isEmpty);
  });

  test('blank text reads nothing', () async {
    expect(await search('   '), isEmpty);
  });

  test('hiding a site refreshes the results', () async {
    await seedSite(db, 's2', owner: 'other', shared: true, name: 'Salt Bay');
    final provider = globalSearchProvider('salt');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    expect((await container.read(provider.future)).single.total, 2);

    await db
        .into(db.siteHides)
        .insert(
          SiteHidesCompanion.insert(
            id: 'h1',
            diverId: 'me',
            siteId: 's2',
            createdAt: 1,
          ),
        );
    await Future<void>.delayed(
      QueryIdSetRunner.changeTickDebounce + const Duration(milliseconds: 200),
    );

    expect((await container.read(provider.future)).single.total, 1);
  });

  test('text no record type can read is a refusal', () async {
    await expectLater(search('"oops'), throwsA(isA<GlobalSearchRefused>()));
  });
}
