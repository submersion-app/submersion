import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';

import '../../../core/services/export/uddf/uddf_observations_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../helpers/test_database.dart';

/// Sightings are a child row, not a column on the dive. `createDive` writes
/// the dive, its tanks, weights, custom fields and gear, and nothing else
/// persists them, so a payload-shape assertion cannot tell whether marine
/// life actually arrives. These read the database back.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  /// Imports one dive and returns its id, so the test can read its child
  /// rows back rather than trusting the payload it handed in.
  Future<String> importDive(Map<String, dynamic> dive) async {
    final diverId = await createTestDiver();
    final data = UddfImportResult(dives: [dive]);
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    final dives = await DiveRepository().getAllDives();
    return dives.single.id;
  }

  test('a sighting row reaches the database, not just its species', () async {
    final diveId = await importDive({
      'dateTime': DateTime.utc(2024, 6, 1, 9, 30),
      'maxDepth': 18.5,
      'sightings': [
        {
          'speciesRef': 'species_giant_manta_ray',
          'speciesName': 'Giant Manta Ray',
          'speciesScientificName': 'Mobula birostris',
          'count': 2,
          'notes': 'cleaning station',
        },
      ],
    });

    final repository = SpeciesRepository();
    final species = await repository.getAllSpecies();
    final manta = species.where((s) => s.commonName == 'Giant Manta Ray');
    expect(manta, hasLength(1), reason: 'the species row must be created');
    expect(manta.single.scientificName, 'Mobula birostris');

    // The child row is the thing this path adds. Asserting only the
    // species would still pass with addSighting removed.
    final sightings = await repository.getSightingsForDive(diveId);
    expect(sightings, hasLength(1), reason: 'the sighting row must be written');
    expect(sightings.single.speciesId, manta.single.id);
    expect(sightings.single.speciesName, 'Giant Manta Ray');
    expect(sightings.single.count, 2);
    expect(sightings.single.notes, 'cleaning station');
  });

  test('one malformed sighting does not cost the dive its others', () async {
    final diveId = await importDive({
      'dateTime': DateTime.utc(2024, 6, 1, 9, 30),
      'sightings': [
        // A number where the name belongs used to throw out of the loop
        // and abort the import rather than skipping the entry.
        {'speciesName': 42, 'count': 1},
        {'speciesName': 'Green Turtle', 'count': 1},
      ],
    });

    final sightings = await SpeciesRepository().getSightingsForDive(diveId);
    expect(sightings, hasLength(1));
    expect(sightings.single.speciesName, 'Green Turtle');
  });
}
