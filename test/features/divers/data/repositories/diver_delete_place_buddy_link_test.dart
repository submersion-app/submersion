import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';

import '../../../../helpers/test_database.dart';
import '../../../media/data/repositories/species_photo_fixtures.dart';

/// A diver's buddies go with the diver. A place that outlives them keeps its
/// name and history and loses only the link, queued for sync (issue #3790).
void main() {
  late AppDatabase db;
  const stale = 1000;

  Future<void> insertPlace(String id, {required String diverId}) => db
      .into(db.equipmentLocations)
      .insert(
        EquipmentLocationsCompanion.insert(
          id: id,
          diverId: Value(diverId),
          name: id,
          kind: const Value('person'),
          buddyId: const Value('anna'),
          createdAt: stale,
          updatedAt: stale,
        ),
      );

  Future<EquipmentLocationRow> placeRow(String id) => (db.select(
    db.equipmentLocations,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<bool> isPending(String id) async =>
      (await db.select(db.syncRecords).get()).any(
        (r) => r.entityType == 'equipmentLocations' && r.recordId == id,
      );

  setUp(() async {
    db = await setUpTestDatabase();
    await insertTestDiver('gone');
    await insertTestDiver('heir');
    await insertTestBuddy(id: 'anna', name: 'Anna', diverId: 'gone');
  });
  tearDown(tearDownTestDatabase);

  test(
    "another diver's place keeps going, unlinked and queued for sync",
    () async {
      await insertPlace('theirs', diverId: 'heir');

      await DiverRepository().deleteDiverWithReassignment('gone');

      final row = await placeRow('theirs');
      expect(row.buddyId, isNull);
      expect(row.kind, 'person');
      expect(row.updatedAt, greaterThan(stale));
      expect(await isPending('theirs'), isTrue);
    },
  );

  test('a place surviving its diver goes to the heir, unlinked', () async {
    await insertPlace('kept', diverId: 'gone');
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Reg',
            type: 'regulator',
            createdAt: stale,
            updatedAt: stale,
            diverId: const Value('heir'),
          ),
        );
    await db
        .into(db.equipmentLocationMoves)
        .insert(
          EquipmentLocationMovesCompanion.insert(
            id: 'move',
            equipmentId: 'reg',
            locationId: const Value('kept'),
            movedAt: stale,
            createdAt: stale,
          ),
        );

    await DiverRepository().deleteDiverWithReassignment('gone');

    final row = await placeRow('kept');
    expect(row.diverId, 'heir');
    expect(row.buddyId, isNull);
    expect(await isPending('kept'), isTrue);
  });
}
