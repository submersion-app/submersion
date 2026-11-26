import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
import 'package:submersion/features/marine_life/domain/species_revamp_ids.dart';

import '../../helpers/test_database.dart';

/// Covers and practice records are keyed by (diver, species), so a merge
/// cannot repoint them: the keeper's win and the duplicate's go (#5027).
void main() {
  late AppDatabase db;
  const keeper = 'diver-keeper';
  const dup = 'diver-dup';

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in [keeper, dup]) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: 'Alex Diver',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
    }
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'grouper',
            commonName: 'Grouper',
            category: 'fish',
          ),
        );
    for (final diver in [keeper, dup]) {
      await db
          .into(db.speciesCovers)
          .insert(
            SpeciesCoversCompanion.insert(
              id: speciesCoverId(diver, 'grouper'),
              diverId: diver,
              speciesId: 'grouper',
              mediaId: Value('m-$diver'),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test("keeper's rows win, the duplicate's are tombstoned", () async {
    await DiverMergeRepository().mergeDivers(
      keeperId: keeper,
      duplicateId: dup,
    );

    final rows = await db.select(db.speciesCovers).get();
    expect(rows.map((r) => r.id), [speciesCoverId(keeper, 'grouper')]);
    expect(rows.single.mediaId, 'm-$keeper');
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'speciesCovers'",
        )
        .get();
    expect(tombstones.map((r) => r.data['record_id']), [
      speciesCoverId(dup, 'grouper'),
    ]);
  });
}
