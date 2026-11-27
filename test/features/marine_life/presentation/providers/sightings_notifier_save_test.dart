import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

import '../../../../helpers/test_database.dart';

/// A new dive's sightings, held until the dive exists, are written with
/// everything the diver gave them, the time included (issue #5092).
void main() {
  late AppDatabase db;
  late SpeciesRepository repository;
  late String jackId;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = SpeciesRepository();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    jackId = (await repository.createSpecies(
      commonName: 'Test Jack',
      category: SpeciesCategory.fish,
    )).id;
  });
  tearDown(tearDownTestDatabase);

  test('saveForDive keeps a held sighting\'s time', () async {
    final notifier = SightingsNotifier(repository, null)
      ..setSightings([
        Sighting(
          id: 'held',
          diveId: '',
          speciesId: jackId,
          speciesName: 'Test Jack',
          seenAtSeconds: 420,
        ),
      ]);
    addTearDown(notifier.dispose);

    await notifier.saveForDive('d1');

    final stored = await repository.getSightingsForDive('d1');
    expect(stored.single.seenAtSeconds, 420);
  });
}
