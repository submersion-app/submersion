import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

import '../../../../helpers/test_database.dart';

/// The expected-species list reads `site_species JOIN species`, so a write to
/// either table has to refresh it. Adding a species touches only
/// `site_species`, and a subscription watching `species` alone never fires:
/// the list on a site page then sits stale until something else rebuilds it.
///
/// Reported against #1156: tapping add on a nearby species left the Expected
/// list unchanged. Three of the four write sites hid it behind a manual
/// `ref.invalidate`, which is why it survived this long.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('adding an expected species refreshes the list on its own', () async {
    const siteId = 'site-1';
    final repository = container.read(speciesRepositoryProvider);

    // site_species.site_id is a real foreign key, so the site has to exist.
    await DatabaseService.instance.database
        .into(DatabaseService.instance.database.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: siteId,
            name: 'Kreidesee',
            createdAt: DateTime(2026).millisecondsSinceEpoch,
            updatedAt: DateTime(2026).millisecondsSinceEpoch,
          ),
        );

    final species = await repository.createSpecies(
      commonName: 'Whale Shark',
      scientificName: 'Rhincodon typus',
      category: SpeciesCategory.shark,
    );

    // Subscribe the way the site page does, and let the first read settle so
    // the provider is live rather than resolved on demand below.
    final sub = container.listen(
      siteExpectedSpeciesProvider(siteId),
      (_, _) {},
    );
    addTearDown(sub.close);
    expect(
      await container.read(siteExpectedSpeciesProvider(siteId).future),
      isEmpty,
    );

    await repository.addExpectedSpecies(siteId: siteId, speciesId: species.id);
    // Let the table-update stream deliver.
    await Future<void>.delayed(Duration.zero);

    final refreshed = await container.read(
      siteExpectedSpeciesProvider(siteId).future,
    );
    expect(refreshed.map((e) => e.speciesId), [
      species.id,
    ], reason: 'the write to site_species must invalidate the list');

    // Removal writes the same table and was stale for the same reason.
    await repository.removeExpectedSpecies(siteId, species.id);
    await Future<void>.delayed(Duration.zero);

    expect(
      await container.read(siteExpectedSpeciesProvider(siteId).future),
      isEmpty,
      reason: 'the delete from site_species must invalidate the list too',
    );
  });
}
