import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

/// Insert a minimal dive (null diverId avoids the divers FK).
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

  test(
    'getSightingsForDives groups by dive id and skips empty dives',
    () async {
      await insertTestDive(id: 'd1');
      await insertTestDive(id: 'd2');
      final species = await repository.createSpecies(
        commonName: 'Test Grouper',
        category: SpeciesCategory.fish,
      );
      final species2 = await repository.createSpecies(
        commonName: 'Test Turtle',
        category: SpeciesCategory.turtle,
      );
      await repository.addSighting(diveId: 'd1', speciesId: species.id);
      await repository.addSighting(diveId: 'd1', speciesId: species2.id);

      final result = await repository.getSightingsForDives(['d1', 'd2']);

      expect(result.keys, ['d1']);
      expect(result['d1'], hasLength(2));
      expect(result['d1']!.first.speciesName, isNotEmpty);
    },
  );

  test('getSightingsForDives returns empty map for empty input', () async {
    expect(await repository.getSightingsForDives([]), isEmpty);
  });

  group('getSpeciesSightedOnDives (issue #4578)', () {
    test('lists each species the dives name once, and no other', () async {
      await insertTestDive(id: 'd1');
      await insertTestDive(id: 'd2');
      await insertTestDive(id: 'd3');
      final grouper = await repository.createSpecies(
        commonName: 'Test Grouper',
        scientificName: 'Epinephelus testus',
        category: SpeciesCategory.fish,
      );
      final turtle = await repository.createSpecies(
        commonName: 'Test Turtle',
        category: SpeciesCategory.turtle,
      );
      await repository.createSpecies(
        commonName: 'Never Seen',
        category: SpeciesCategory.other,
      );
      await repository.addSighting(diveId: 'd1', speciesId: grouper.id);
      await repository.addSighting(diveId: 'd2', speciesId: grouper.id);
      await repository.addSighting(diveId: 'd3', speciesId: turtle.id);

      final sighted = await repository.getSpeciesSightedOnDives(['d1', 'd2']);

      expect(sighted.map((s) => s.id), [grouper.id]);
      expect(sighted.single.scientificName, 'Epinephelus testus');
    });

    test('reads past the bound variable limit', () async {
      final species = await repository.createSpecies(
        commonName: 'Test Ray',
        category: SpeciesCategory.ray,
      );
      await insertTestDive(id: 'last');
      await repository.addSighting(diveId: 'last', speciesId: species.id);
      final ids = [for (var i = 0; i < 1000; i++) 'missing-$i', 'last'];

      final sighted = await repository.getSpeciesSightedOnDives(ids);

      expect(sighted.map((s) => s.id), [species.id]);
    });

    test('orders species from several chunks as getAllSpecies does', () async {
      // Three dives past one chunk apart, each sighting a different species,
      // so the rows arrive from separate queries in no useful order.
      final turtle = await repository.createSpecies(
        commonName: 'Zebra Turtle',
        category: SpeciesCategory.turtle,
      );
      final fishB = await repository.createSpecies(
        commonName: 'Blenny',
        category: SpeciesCategory.fish,
      );
      final fishA = await repository.createSpecies(
        commonName: 'Angelfish',
        category: SpeciesCategory.fish,
      );
      for (final (dive, species) in [
        ('first', turtle),
        ('second', fishB),
        ('third', fishA),
      ]) {
        await insertTestDive(id: dive);
        await repository.addSighting(diveId: dive, speciesId: species.id);
      }
      final ids = [
        'first',
        for (var i = 0; i < 900; i++) 'gap-a-$i',
        'second',
        for (var i = 0; i < 900; i++) 'gap-b-$i',
        'third',
      ];

      final sighted = await repository.getSpeciesSightedOnDives(ids);

      expect(
        sighted.map((s) => s.id),
        (await repository.getAllSpecies(
          ids: [turtle.id, fishB.id, fishA.id],
        )).map((s) => s.id),
      );
      expect(sighted.map((s) => s.commonName), [
        'Angelfish',
        'Blenny',
        'Zebra Turtle',
      ]);
    });

    test('returns nothing for no dives', () async {
      expect(await repository.getSpeciesSightedOnDives([]), isEmpty);
    });
  });
}
