import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_location_retirement.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  Future<void> place(String id) => db
      .into(db.equipmentLocations)
      .insert(
        EquipmentLocationsCompanion.insert(
          id: id,
          name: id,
          createdAt: 1,
          updatedAt: 1,
          diverId: const Value('gone'),
        ),
      );

  Future<void> move(String id, String equipmentId, String placeId, int at) => db
      .into(db.equipmentLocationMoves)
      .insert(
        EquipmentLocationMovesCompanion.insert(
          id: id,
          equipmentId: equipmentId,
          locationId: Value(placeId),
          movedAt: at,
          createdAt: at,
        ),
      );

  Future<void> gear(String id, String owner) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          createdAt: 1,
          updatedAt: 1,
          diverId: Value(owner),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['gone', 'heir', 'friend']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    // Gear the deleted diver transferred earlier: now heir's.
    await gear('reg', 'heir');
    await place('used');
    await place('unused');
    await move('m', 'reg', 'used', 1);
  });

  tearDown(tearDownTestDatabase);

  Future<void> retire() => db.transaction(
    () => retireDiverEquipmentLocations(db, SyncRepository(), 'gone', now: 9),
  );

  test('a place surviving gear uses moves to that gear\'s owner', () async {
    await retire();
    final rows = await db.select(db.equipmentLocations).get();
    expect({for (final r in rows) r.id: r.diverId}, {'used': 'heir'});
    expect(rows.single.updatedAt, 9);
    final pending = await db.select(db.syncRecords).get();
    expect(
      pending.where(
        (r) => r.entityType == 'equipmentLocations' && r.recordId == 'used',
      ),
      isNotEmpty,
    );
  });

  test('an unused place is deleted and tombstoned', () async {
    await retire();
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      [
        for (final t in tombstones)
          if (t.entityType == 'equipmentLocations') t.recordId,
      ],
      ['unused'],
    );
  });

  test(
    'a place on two owners\' gear goes to the earliest move\'s owner',
    () async {
      await gear('bcd', 'friend');
      await move('earlier', 'bcd', 'used', 0);
      await retire();
      final row = await (db.select(
        db.equipmentLocations,
      )..where((t) => t.id.equals('used'))).getSingle();
      expect(row.diverId, 'friend');
    },
  );

  test('another diver\'s places are untouched', () async {
    await db
        .into(db.equipmentLocations)
        .insert(
          EquipmentLocationsCompanion.insert(
            id: 'theirs',
            name: 'theirs',
            createdAt: 1,
            updatedAt: 1,
            diverId: const Value('heir'),
          ),
        );
    await retire();
    final ids = {
      for (final r in await db.select(db.equipmentLocations).get()) r.id,
    };
    expect(ids, containsAll(['theirs', 'used']));
  });
}
