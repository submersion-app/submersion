import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Helper to insert a minimal dive into the test database.
/// Uses null diverId to avoid FK constraint on the divers table.
Future<void> insertTestDive({required String id}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

void main() {
  late SpeciesRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SpeciesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('SpeciesRepository', () {
    group('CRUD operations', () {
      test(
        'createSpecies creates a custom species with generated ID',
        () async {
          final species = await repository.createSpecies(
            commonName: 'Test Clownfish',
            scientificName: 'Amphiprion testus',
            category: SpeciesCategory.fish,
            taxonomyClass: 'Actinopterygii',
            description: 'A test species',
          );

          expect(species.id, isNotEmpty);
          expect(species.commonName, 'Test Clownfish');
          expect(species.scientificName, 'Amphiprion testus');
          expect(species.category, SpeciesCategory.fish);
          expect(species.taxonomyClass, 'Actinopterygii');
          expect(species.description, 'A test species');
          expect(species.isBuiltIn, false);
        },
      );

      test('createSpecies with minimal fields', () async {
        final species = await repository.createSpecies(
          commonName: 'Mystery Fish',
          category: SpeciesCategory.other,
        );

        expect(species.commonName, 'Mystery Fish');
        expect(species.scientificName, isNull);
        expect(species.taxonomyClass, isNull);
        expect(species.description, isNull);
        expect(species.isBuiltIn, false);
      });

      test('getSpeciesById returns created species', () async {
        final created = await repository.createSpecies(
          commonName: 'Blue Tang',
          scientificName: 'Paracanthurus hepatus',
          category: SpeciesCategory.fish,
        );

        final fetched = await repository.getSpeciesById(created.id);

        expect(fetched, isNotNull);
        expect(fetched!.id, created.id);
        expect(fetched.commonName, 'Blue Tang');
        expect(fetched.scientificName, 'Paracanthurus hepatus');
      });

      test('getSpeciesById returns null for non-existent ID', () async {
        final result = await repository.getSpeciesById('non-existent-id');
        expect(result, isNull);
      });

      test('updateSpecies modifies species fields', () async {
        final created = await repository.createSpecies(
          commonName: 'Original Name',
          category: SpeciesCategory.fish,
        );

        await repository.updateSpecies(
          created.copyWith(
            commonName: 'Updated Name',
            scientificName: 'Genus species',
            taxonomyClass: 'Actinopterygii',
            description: 'Updated description',
          ),
        );

        final updated = await repository.getSpeciesById(created.id);
        expect(updated!.commonName, 'Updated Name');
        expect(updated.scientificName, 'Genus species');
        expect(updated.taxonomyClass, 'Actinopterygii');
        expect(updated.description, 'Updated description');
      });

      test('deleteSpecies removes species', () async {
        final created = await repository.createSpecies(
          commonName: 'To Delete',
          category: SpeciesCategory.invertebrate,
        );

        await repository.deleteSpecies(created.id);

        final result = await repository.getSpeciesById(created.id);
        expect(result, isNull);
      });

      test('deleteSpecies throws when species is in use', () async {
        final species = await repository.createSpecies(
          commonName: 'In Use Species',
          category: SpeciesCategory.fish,
        );

        await insertTestDive(id: 'test-dive-1');

        await repository.addSighting(
          diveId: 'test-dive-1',
          speciesId: species.id,
        );

        expect(() => repository.deleteSpecies(species.id), throwsException);
      });
    });

    group('isSpeciesInUse', () {
      test('returns false for unused species', () async {
        final species = await repository.createSpecies(
          commonName: 'Unused Species',
          category: SpeciesCategory.coral,
        );

        expect(await repository.isSpeciesInUse(species.id), false);
      });

      test('returns true for species with sightings', () async {
        final species = await repository.createSpecies(
          commonName: 'Used Species',
          category: SpeciesCategory.fish,
        );

        await insertTestDive(id: 'dive-for-use-test');

        await repository.addSighting(
          diveId: 'dive-for-use-test',
          speciesId: species.id,
        );

        expect(await repository.isSpeciesInUse(species.id), true);
      });
    });

    group('getAllSpecies', () {
      test('returns all species sorted by category then name', () async {
        await repository.createSpecies(
          commonName: 'Zebra Moray',
          category: SpeciesCategory.fish,
        );
        await repository.createSpecies(
          commonName: 'Blue Nudibranch',
          category: SpeciesCategory.invertebrate,
        );
        await repository.createSpecies(
          commonName: 'Anemonefish',
          category: SpeciesCategory.fish,
        );

        final all = await repository.getAllSpecies();

        expect(all.length, 3);
        // fish comes before invertebrate alphabetically
        expect(all[0].commonName, 'Anemonefish');
        expect(all[1].commonName, 'Zebra Moray');
        expect(all[2].commonName, 'Blue Nudibranch');
      });
    });

    group('getSpeciesByCategory', () {
      test('returns only species in requested category', () async {
        await repository.createSpecies(
          commonName: 'Whale Shark',
          category: SpeciesCategory.shark,
        );
        await repository.createSpecies(
          commonName: 'Clownfish',
          category: SpeciesCategory.fish,
        );
        await repository.createSpecies(
          commonName: 'Nurse Shark',
          category: SpeciesCategory.shark,
        );

        final sharks = await repository.getSpeciesByCategory(
          SpeciesCategory.shark,
        );

        expect(sharks.length, 2);
        expect(sharks.every((s) => s.category == SpeciesCategory.shark), true);
      });
    });

    group('searchSpecies', () {
      test('finds species by common name', () async {
        await repository.createSpecies(
          commonName: 'Green Sea Turtle',
          category: SpeciesCategory.turtle,
        );
        await repository.createSpecies(
          commonName: 'Hawksbill Turtle',
          category: SpeciesCategory.turtle,
        );
        await repository.createSpecies(
          commonName: 'Clownfish',
          category: SpeciesCategory.fish,
        );

        final results = await repository.searchSpecies('turtle');
        expect(results.length, 2);
      });

      test('finds species by scientific name', () async {
        await repository.createSpecies(
          commonName: 'Ocellaris Clownfish',
          scientificName: 'Amphiprion ocellaris',
          category: SpeciesCategory.fish,
        );

        final results = await repository.searchSpecies('amphiprion');
        expect(results.length, 1);
        expect(results[0].commonName, 'Ocellaris Clownfish');
      });

      test('finds species by taxonomy class', () async {
        await repository.createSpecies(
          commonName: 'Great White Shark',
          category: SpeciesCategory.shark,
          taxonomyClass: 'Chondrichthyes',
        );
        await repository.createSpecies(
          commonName: 'Clownfish',
          category: SpeciesCategory.fish,
          taxonomyClass: 'Actinopterygii',
        );

        final results = await repository.searchSpecies('chondrichthyes');
        expect(results.length, 1);
        expect(results[0].commonName, 'Great White Shark');
      });

      test('search is case insensitive', () async {
        await repository.createSpecies(
          commonName: 'Blue Whale',
          category: SpeciesCategory.mammal,
        );

        final results = await repository.searchSpecies('BLUE WHALE');
        expect(results.length, 1);
      });
    });

    group('sightings', () {
      late String diveId;
      late domain.Species testSpecies;

      setUp(() async {
        diveId = 'sighting-test-dive';
        await insertTestDive(id: diveId);

        testSpecies = await repository.createSpecies(
          commonName: 'Test Lionfish',
          category: SpeciesCategory.fish,
        );
      });

      test(
        'addSighting creates a sighting linked to dive and species',
        () async {
          final sighting = await repository.addSighting(
            diveId: diveId,
            speciesId: testSpecies.id,
            count: 3,
            notes: 'Spotted near coral',
          );

          expect(sighting.id, isNotEmpty);
          expect(sighting.diveId, diveId);
          expect(sighting.speciesId, testSpecies.id);
          expect(sighting.speciesName, 'Test Lionfish');
          expect(sighting.count, 3);
          expect(sighting.notes, 'Spotted near coral');
        },
      );

      test('getSightingsForDive returns all sightings for a dive', () async {
        final species2 = await repository.createSpecies(
          commonName: 'Test Moray Eel',
          category: SpeciesCategory.fish,
        );

        await repository.addSighting(diveId: diveId, speciesId: testSpecies.id);
        await repository.addSighting(
          diveId: diveId,
          speciesId: species2.id,
          count: 2,
        );

        final sightings = await repository.getSightingsForDive(diveId);
        expect(sightings.length, 2);
      });

      test('deleteSighting removes sighting', () async {
        final sighting = await repository.addSighting(
          diveId: diveId,
          speciesId: testSpecies.id,
        );

        await repository.deleteSighting(sighting.id);

        final sightings = await repository.getSightingsForDive(diveId);
        expect(sightings.isEmpty, true);
      });

      test('deleteSightingsForDive removes all sightings for a dive', () async {
        final species2 = await repository.createSpecies(
          commonName: 'Octopus',
          category: SpeciesCategory.invertebrate,
        );

        await repository.addSighting(diveId: diveId, speciesId: testSpecies.id);
        await repository.addSighting(diveId: diveId, speciesId: species2.id);

        await repository.deleteSightingsForDive(diveId);

        final sightings = await repository.getSightingsForDive(diveId);
        expect(sightings.isEmpty, true);
      });
    });

    group('getOrCreateSpecies', () {
      test('creates new species when none exists', () async {
        final species = await repository.getOrCreateSpecies(
          commonName: 'Brand New Species',
          category: SpeciesCategory.coral,
        );

        expect(species.id, isNotEmpty);
        expect(species.commonName, 'Brand New Species');
        expect(species.category, SpeciesCategory.coral);
      });

      test(
        'returns existing species when name matches (case insensitive)',
        () async {
          final created = await repository.createSpecies(
            commonName: 'Manta Ray',
            scientificName: 'Mobula birostris',
            category: SpeciesCategory.ray,
          );

          final found = await repository.getOrCreateSpecies(
            commonName: 'manta ray',
            category: SpeciesCategory.ray,
          );

          expect(found.id, created.id);
          expect(found.scientificName, 'Mobula birostris');
        },
      );
    });
  });
}
