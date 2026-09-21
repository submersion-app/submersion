import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
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

  Future<void> importDive(Map<String, dynamic> dive) async {
    final diverId = await createTestDiver();
    final data = UddfImportResult(dives: [dive]);
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
    );
  }

  test('a sighting reaches the database with its species created', () async {
    await importDive({
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
  });
}
