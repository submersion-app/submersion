import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_sightings_hydration.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_observations_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// Issue #4578: a dives only UDDF (dive list, dive page, buddy share) wrote
/// each sighting's `speciesref` but declared no species, so the link
/// pointed at nothing and a re-import named the species after its UUID.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  /// Seeds one dive with one sighting, plus a species nobody saw, and exports
  /// the dive the way the dive list does.
  Future<({String xml, String speciesId})> seedAndExport() async {
    final diverId = await createTestDiver();
    final species = SpeciesRepository();
    final glaucus = await species.createSpecies(
      commonName: 'Blue Dragon',
      scientificName: 'Glaucus atlanticus',
      category: SpeciesCategory.invertebrate,
      taxonomyClass: 'Gastropoda',
    );
    await species.createSpecies(
      commonName: 'Unseen Shrimp',
      category: SpeciesCategory.invertebrate,
    );
    final dives = DiveRepository();
    await dives.createDive(
      domain.Dive(id: 'd1', dateTime: DateTime(2026, 3, 1, 9)),
    );
    await species.addSighting(
      diveId: 'd1',
      speciesId: glaucus.id,
      abundance: SightingAbundance.exact,
      count: 3,
    );

    const options = UddfExportOptions();
    final selected = await hydrateMarineSightings(
      await dives.getDivesByIds(['d1']),
      repository: species,
    );
    final xml = await UddfExportService().generateDivesUddfContent(
      selected,
      extras: await resolveDivesExtras(
        BuddyRepository(),
        EquipmentComponentRepository(),
        DiveRoleRepository(),
        diverId,
        ['d1'],
        options,
        species: species,
      ),
      options: options,
    );
    return (xml: xml, speciesId: glaucus.id);
  }

  test('declares the species each sighting references, and no other', () async {
    final seeded = await seedAndExport();
    final doc = XmlDocument.parse(seeded.xml);

    final ref = doc
        .findAllElements('sighting')
        .single
        .getAttribute('speciesref');
    final specs = doc.findAllElements('spec').toList();
    expect(specs.map((s) => s.getAttribute('id')), [ref]);
    expect(ref, 'species_${seeded.speciesId}');
    expect(specs.single.getElement('commonname')?.innerText, 'Blue Dragon');
    expect(
      specs.single.getElement('scientificname')?.innerText,
      'Glaucus atlanticus',
    );
  });

  test('a re-import names the species, not its UUID', () async {
    final seeded = await seedAndExport();

    await tearDownTestDatabase();
    await setUpTestDatabase();
    final diverId = await createTestDiver();
    final parsed = await ExportService().importAllDataFromUddf(seeded.xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: diverId,
    );

    final restored = (await DiveRepository().getAllDives()).single;
    final sighting = (await SpeciesRepository().getSightingsForDive(
      restored.id,
    )).single;
    final species = await SpeciesRepository().getSpeciesById(
      sighting.speciesId,
    );
    expect(species?.commonName, 'Blue Dragon');
    expect(species?.scientificName, 'Glaucus atlanticus');
    expect(species?.category, SpeciesCategory.invertebrate);
    expect(sighting.count, 3);
  });
}
