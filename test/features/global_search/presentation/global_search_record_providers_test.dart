import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_record_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/shared_items_fixture.dart';
import '../../../helpers/test_database.dart';

/// Each section's records, read by id through its list's own repository
/// read (issue #4247), against a real database.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['me']);
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

  Future<T> read<T>(FutureProvider<T> Function(String key) family) async {
    final provider = family(globalSearchIdsKey(['s1', 't1', 'missing']));
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    return container.read(provider.future);
  }

  test('sites and trips hold the shown records alone', () async {
    final sites = await read(globalSearchSitesProvider.call);
    final trips = await read(globalSearchTripsProvider.call);

    expect([for (final e in sites) e.site.id], ['s1']);
    expect([for (final e in trips) e.trip.id], ['t1']);
  });

  test('every other section reads nothing for ids it does not hold', () async {
    expect(await read(globalSearchEquipmentProvider.call), isEmpty);
    expect(await read(globalSearchEquipmentSetsProvider.call), isEmpty);
    expect(await read(globalSearchBuddiesProvider.call), isEmpty);
    expect(await read(globalSearchDiveCentersProvider.call), isEmpty);
    expect(await read(globalSearchDiveCenterCountsProvider.call), isEmpty);
    expect(await read(globalSearchCertificationsProvider.call), isEmpty);
    expect(await read(globalSearchCoursesProvider.call), isEmpty);
    expect(await read(globalSearchSpeciesProvider.call), isEmpty);
    expect(await read(globalSearchSeenSpeciesProvider.call), isEmpty);
    expect(await read(globalSearchSpeciesCoversProvider.call), isEmpty);
    expect(await read(globalSearchDocumentsProvider.call), isEmpty);
    expect(await read(globalSearchDocumentTagsProvider.call), isEmpty);
    expect(await read(globalSearchDivePlansProvider.call), isEmpty);
    expect(await read(globalSearchGpsTracksProvider.call), isEmpty);
    expect(await read(globalSearchUnderwaterRoutesProvider.call), isEmpty);
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
