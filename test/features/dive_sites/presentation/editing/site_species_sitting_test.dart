import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_start.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_species_sitting.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A site's expected species are held in the sitting and written at Save
/// as the difference from what the sitting loaded (issue #4527, phase 2).
void main() {
  late SpeciesRepository repository;
  late Species turtle;
  late Species manta;
  late Species shark;
  const site = DiveSite(id: 's1', name: 'A');

  setUp(() async {
    await setUpTestDatabase();
    repository = SpeciesRepository();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'A', 0, 0)",
    );
    turtle = await repository.createSpecies(
      commonName: 'Green turtle',
      category: SpeciesCategory.turtle,
    );
    manta = await repository.createSpecies(
      commonName: 'Manta',
      category: SpeciesCategory.ray,
    );
    shark = await repository.createSpecies(
      commonName: 'Reef shark',
      category: SpeciesCategory.shark,
    );
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> storedIds() async => [
    for (final e in await repository.getExpectedSpeciesForSite('s1'))
      e.speciesId,
  ];

  Future<EditSession<DiveSite>> loaded() async {
    final session = EditSession<DiveSite>(site);
    addTearDown(session.dispose);
    await siteSpeciesList.load(session);
    return session;
  }

  test('removing and adding writes only the difference', () async {
    await repository.addExpectedSpecies(siteId: 's1', speciesId: turtle.id);
    final session = await loaded();

    siteSpeciesList.set(session, [newSiteSpeciesEntry('s1', manta)]);
    await session.runHeldWrites();

    expect(await storedIds(), [manta.id]);
  });

  test('a species added on another device meanwhile survives', () async {
    await repository.addExpectedSpecies(siteId: 's1', speciesId: turtle.id);
    final session = await loaded();
    siteSpeciesList.set(session, [
      ...siteSpeciesList.loaded(session)!,
      newSiteSpeciesEntry('s1', manta),
    ]);
    // Stored underneath meanwhile.
    await repository.addExpectedSpecies(siteId: 's1', speciesId: shark.id);

    await session.runHeldWrites();

    expect((await storedIds()).toSet(), {turtle.id, manta.id, shark.id});
  });

  test('picking the same species again is no change', () async {
    await repository.addExpectedSpecies(siteId: 's1', speciesId: turtle.id);
    final session = await loaded();

    siteSpeciesList.set(session, [newSiteSpeciesEntry('s1', turtle)]);

    expect(session.isDirty, isFalse);
  });

  test('a held list is a write of the species field', () async {
    final session = await loaded();
    siteSpeciesList.set(session, [newSiteSpeciesEntry('s1', manta)]);

    expect(siteLibraryFields(session), {'species'});
  });
}
