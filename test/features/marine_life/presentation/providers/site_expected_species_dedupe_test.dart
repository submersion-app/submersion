import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

import '../../../../helpers/test_database.dart';

/// `site_species` carries a per-row uuid primary key and only a non-unique
/// index on `site_id`, so nothing in the schema stops the same species being
/// expected at a site twice. Every UI path in reach of a double tap therefore
/// depends on the notifier refusing the second add.
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

  const siteId = 'site-1';

  Future<domain.Species> seed() async {
    final db = DatabaseService.instance.database;
    // site_species.site_id is a real foreign key, so the site has to exist.
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: siteId,
            name: 'Kreidesee',
            createdAt: DateTime(2026).millisecondsSinceEpoch,
            updatedAt: DateTime(2026).millisecondsSinceEpoch,
          ),
        );
    return container
        .read(speciesRepositoryProvider)
        .createSpecies(
          commonName: 'Whale Shark',
          scientificName: 'Rhincodon typus',
          category: SpeciesCategory.shark,
        );
  }

  test('two adds racing on the same species insert one row', () async {
    final species = await seed();
    final notifier = container.read(
      siteExpectedSpeciesNotifierProvider(siteId).notifier,
    );
    await Future<void>.delayed(Duration.zero); // initial load

    // Two chips carrying synonyms of one species resolve to the same id, so
    // guarding on the typed name upstream does not cover this. Both calls
    // start before either has written, which is what makes a check-then-act
    // guard after an await useless.
    await Future.wait([
      notifier.addSpecies(species.id),
      notifier.addSpecies(species.id),
    ]);

    final rows = await container
        .read(speciesRepositoryProvider)
        .getExpectedSpeciesForSite(siteId);
    expect(rows, hasLength(1));
    expect(
      container.read(siteExpectedSpeciesNotifierProvider(siteId)),
      hasLength(1),
    );
  });

  test('adding a species that is already expected is a no-op', () async {
    final species = await seed();
    final notifier = container.read(
      siteExpectedSpeciesNotifierProvider(siteId).notifier,
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.addSpecies(species.id);
    await notifier.addSpecies(species.id);

    final rows = await container
        .read(speciesRepositoryProvider)
        .getExpectedSpeciesForSite(siteId);
    expect(rows, hasLength(1));
  });
}
