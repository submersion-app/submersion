import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_record_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/shared_items_fixture.dart';
import '../../../helpers/test_database.dart';
import '../helpers/scoped_records_fixture.dart';

/// Each section's records, read by id through its list's own repository
/// read (issue #4247), against a real database that holds three records of
/// every kind: a family that dropped its ids would read all three.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedScopedRecords(db, diverId: 'me');
    await seedSite(db, 's1', owner: 'me');
    await seedSite(db, 's2', owner: 'me');
    await seedTrip(db, 't1', owner: 'me');
    container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  Future<T> read<T>(
    FutureProvider<T> Function(String key) family,
    List<String> ids,
  ) async {
    final provider = family(globalSearchIdsKey(ids));
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    return container.read(provider.future);
  }

  const shown = ['charlie', 'alpha', 'missing'];
  const found = {'alpha', 'charlie'};

  test('sites and trips hold the shown records alone', () async {
    final sites = await read(globalSearchSitesProvider.call, ['s1', 'x']);
    final trips = await read(globalSearchTripsProvider.call, ['t1', 'x']);

    expect([for (final e in sites) e.site.id], ['s1']);
    expect([for (final e in trips) e.trip.id], ['t1']);
  });

  test('every other section holds the shown records alone', () async {
    Future<Set<String>> idsOf<T>(
      FutureProvider<Iterable<T>> Function(String key) family,
      String Function(T record) idOf, {
      List<String> ids = shown,
    }) async => {for (final r in await read(family, ids)) idOf(r)};
    Future<Set<String>> keysOf(
      FutureProvider<Map<String, Object?>> Function(String key) family, {
      List<String> ids = shown,
    }) async => (await read(family, ids)).keys.toSet();

    expect(await idsOf(globalSearchEquipmentProvider.call, (e) => e.id), found);
    expect(
      await idsOf(globalSearchEquipmentSetsProvider.call, (e) => e.id),
      found,
    );
    expect(
      await idsOf(globalSearchBuddiesProvider.call, (e) => e.buddy.id),
      found,
    );
    const centers = ['center-charlie', 'center-alpha'];
    expect(
      await idsOf(
        globalSearchDiveCentersProvider.call,
        (e) => e.id,
        ids: centers,
      ),
      centers.toSet(),
    );
    expect(
      await keysOf(globalSearchDiveCenterCountsProvider.call, ids: centers),
      centers.toSet(),
    );
    expect(
      await idsOf(globalSearchCertificationsProvider.call, (e) => e.id),
      found,
    );
    expect(await idsOf(globalSearchCoursesProvider.call, (e) => e.id), found);
    expect(await idsOf(globalSearchSpeciesProvider.call, (e) => e.id), found);
    expect(await keysOf(globalSearchSeenSpeciesProvider.call), found);
    expect(await keysOf(globalSearchSpeciesCoversProvider.call), found);
    expect(
      await idsOf(globalSearchDocumentsProvider.call, (e) => e.document.id),
      found,
    );
    expect(await keysOf(globalSearchDocumentTagsProvider.call), found);
    // alpha's saved series brings bravo, which its row counts.
    expect(await idsOf(globalSearchDivePlansProvider.call, (e) => e.id), {
      ...found,
      'bravo',
    });
    expect(await idsOf(globalSearchGpsTracksProvider.call, (e) => e.id), found);
    expect(
      await idsOf(globalSearchUnderwaterRoutesProvider.call, (e) => e.id),
      found,
    );
  });

  test('documents read nothing without a diver, as their list does', () async {
    final noDiver = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(noDiver.dispose);
    final provider = globalSearchDocumentsProvider(globalSearchIdsKey(['d']));
    final sub = noDiver.listen(provider, (_, _) {});
    addTearDown(sub.close);

    expect(await noDiver.read(provider.future), isEmpty);
  });
}
