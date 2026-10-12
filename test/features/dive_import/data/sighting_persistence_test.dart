import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
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

  group('species from the file (#3033)', () {
    test('a new species keeps the category, taxonomy and description '
        'the file gives', () async {
      final diveId = await importDive({
        'dateTime': DateTime.utc(2024, 6, 1, 9, 30),
        'sightings': [
          {
            'speciesRef': 'species_grande_crevette_rose',
            'speciesName': 'Grande crevette rose',
            'speciesScientificName': 'Palaemon serratus',
            'speciesCategory': SpeciesCategory.invertebrate,
            'speciesTaxonomyClass': 'Malacostraca',
            'speciesDescription': 'Rock pools',
          },
        ],
      });

      final repository = SpeciesRepository();
      final sighting = (await repository.getSightingsForDive(diveId)).single;
      final species = await repository.getSpeciesById(sighting.speciesId);
      expect(species?.commonName, 'Grande crevette rose');
      expect(species?.scientificName, 'Palaemon serratus');
      expect(species?.category, SpeciesCategory.invertebrate);
      expect(species?.taxonomyClass, 'Malacostraca');
      expect(species?.description, 'Rock pools');
    });

    test('a name in another language attaches to the species with the same '
        'scientific name', () async {
      final repository = SpeciesRepository();
      final octopus = await repository.createSpecies(
        commonName: 'Common Octopus',
        scientificName: 'Octopus vulgaris',
        category: SpeciesCategory.invertebrate,
      );

      final diveId = await importDive({
        'dateTime': DateTime.utc(2024, 6, 1, 9, 30),
        'sightings': [
          {
            'speciesRef': 'species_pieuvre_commune',
            'speciesName': 'Pieuvre commune',
            'speciesScientificName': 'Octopus vulgaris',
          },
        ],
      });

      final sighting = (await repository.getSightingsForDive(diveId)).single;
      expect(sighting.speciesId, octopus.id);
      expect(await repository.getAllSpecies(), hasLength(1));
    });

    test('a spec with only a scientific name names the species by it, '
        'not by its ref', () async {
      final diveId = await importDive({
        'dateTime': DateTime.utc(2024, 6, 1, 9, 30),
        'sightings': [
          {
            'speciesRef': 'species_3f2a9c1e-77b0-4c5e-9d2a-1b6e0f4c8a21',
            'speciesScientificName': 'Palaemon serratus',
          },
        ],
      });

      final sighting = (await SpeciesRepository().getSightingsForDive(
        diveId,
      )).single;
      expect(sighting.speciesName, 'Palaemon serratus');
    });

    test('a ref the species section does not declare still names the '
        'species', () async {
      final diveId = await importDive({
        'dateTime': DateTime.utc(2024, 6, 1, 9, 30),
        'sightings': [
          {'speciesRef': 'species_mystery_fish'},
        ],
      });

      final sighting = (await SpeciesRepository().getSightingsForDive(
        diveId,
      )).single;
      expect(sighting.speciesName, 'Mystery Fish');
    });

    test('a UDDF file with a species section imports in one pass', () async {
      const doc = '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="rg">
      <dive id="d1">
        <informationbeforedive>
          <divenumber>1</divenumber>
          <datetime>2026-01-15T09:00:00</datetime>
        </informationbeforedive>
        <samples>
          <waypoint><depth>5</depth><divetime>0</divetime></waypoint>
          <waypoint><depth>5</depth><divetime>60</divetime></waypoint>
        </samples>
        <informationafterdive>
          <sightings>
            <sighting speciesref="species_grande_crevette_rose" count="4"/>
          </sightings>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
  <applicationdata>
    <submersion version="1.0">
      <species>
        <spec id="species_grande_crevette_rose">
          <commonname>Grande crevette rose</commonname>
          <scientificname>Palaemon serratus</scientificname>
          <category>invertebrate</category>
        </spec>
      </species>
    </submersion>
  </applicationdata>
</uddf>''';
      final diverId = await createTestDiver();
      final data = await UddfFullImportService().importAllDataFromUddf(doc);
      await UddfEntityImporter().import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: buildRepositories(),
        diverId: diverId,
      );

      final repository = SpeciesRepository();
      final diveId = (await DiveRepository().getAllDives()).single.id;
      final sighting = (await repository.getSightingsForDive(diveId)).single;
      expect(sighting.speciesName, 'Grande crevette rose');
      expect(sighting.count, 4);
      final species = await repository.getSpeciesById(sighting.speciesId);
      expect(species?.scientificName, 'Palaemon serratus');
      expect(species?.category, SpeciesCategory.invertebrate);
    });
  });
}
