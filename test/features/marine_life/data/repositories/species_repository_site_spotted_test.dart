import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

Future<void> _insertSite(String id) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value('Site $id'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> _insertDive(String id, {required String siteId}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          siteId: Value(siteId),
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

  group('getSpeciesSpottedAtSite', () {
    test('counts every dive at the site when no dive is excluded', () async {
      await _insertSite('s1');
      await _insertDive('d1', siteId: 's1');
      await _insertDive('d2', siteId: 's1');
      final turtle = await repository.createSpecies(
        commonName: 'Test Turtle',
        category: SpeciesCategory.turtle,
      );
      await repository.addSighting(diveId: 'd1', speciesId: turtle.id);
      await repository.addSighting(diveId: 'd2', speciesId: turtle.id);

      final spotted = await repository.getSpeciesSpottedAtSite('s1');

      expect(spotted.single.diveCount, 2);
    });

    test('leaves out the sightings of the excluded dive', () async {
      await _insertSite('s1');
      await _insertDive('d1', siteId: 's1');
      await _insertDive('d2', siteId: 's1');
      final turtle = await repository.createSpecies(
        commonName: 'Test Turtle',
        category: SpeciesCategory.turtle,
      );
      final grouper = await repository.createSpecies(
        commonName: 'Test Grouper',
        category: SpeciesCategory.fish,
      );
      await repository.addSighting(
        diveId: 'd1',
        speciesId: turtle.id,
        count: 3,
      );
      await repository.addSighting(diveId: 'd2', speciesId: turtle.id);
      await repository.addSighting(diveId: 'd2', speciesId: grouper.id);

      final spotted = await repository.getSpeciesSpottedAtSite(
        's1',
        excludeDiveId: 'd2',
      );

      expect(spotted.map((s) => s.speciesId), [turtle.id]);
      expect(spotted.single.diveCount, 1);
    });
  });
}
