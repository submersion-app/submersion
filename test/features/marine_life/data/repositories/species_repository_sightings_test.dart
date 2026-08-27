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
}
