import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';

import '../../../../helpers/test_database.dart';

/// A diver's dive centers go with the diver. A place that outlives them
/// keeps its name and history and loses only the link, and the change is
/// queued for sync: the schema's SET NULL reaches no peer (issue #3623).
void main() {
  late AppDatabase db;
  const stale = 1000;

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(
          id: id,
          name: id,
          createdAt: stale,
          updatedAt: stale,
        ),
      );

  Future<void> insertPlace(String id, {required String diverId}) => db
      .into(db.equipmentLocations)
      .insert(
        EquipmentLocationsCompanion.insert(
          id: id,
          diverId: Value(diverId),
          name: id,
          kind: const Value('diveCenter'),
          diveCenterId: const Value('center'),
          createdAt: stale,
          updatedAt: stale,
        ),
      );

  Future<EquipmentLocationRow> placeRow(String id) => (db.select(
    db.equipmentLocations,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<bool> isPending(String id) async {
    final rows = await db.select(db.syncRecords).get();
    return rows.any(
      (r) => r.entityType == 'equipmentLocations' && r.recordId == id,
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDiver('gone');
    await insertDiver('heir');
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion.insert(
            id: 'center',
            name: 'center',
            diverId: const Value('gone'),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test(
    "another diver's place keeps going, unlinked and queued for sync",
    () async {
      await insertPlace('theirs', diverId: 'heir');

      await DiverRepository().deleteDiverWithReassignment('gone');

      final row = await placeRow('theirs');
      expect(row.diveCenterId, isNull);
      expect(row.name, 'theirs');
      expect(row.kind, 'diveCenter');
      expect(row.updatedAt, greaterThan(stale));
      expect(await isPending('theirs'), isTrue);
    },
  );

  test('a place deleted with its diver is never queued for sync', () async {
    await insertPlace('unused', diverId: 'gone');

    await DiverRepository().deleteDiverWithReassignment('gone');

    expect(await isPending('unused'), isFalse);
  });

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
    expect(row.diveCenterId, isNull);
    expect(await isPending('kept'), isTrue);
  });
}
