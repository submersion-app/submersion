import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final (id, isDefault) in [('owner', true), ('wife', false)]) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              isDefault: Value(isDefault),
            ),
          );
    }
    for (final (id, owner) in [('bcd', 'owner'), ('mask', 'wife')]) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'bcd',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
    }
    final shares = EquipmentShareRepository();
    await shares.shareMany(
      equipmentIds: ['bcd'],
      diverIds: ['wife'],
      actingDiverId: 'owner',
    );
    await shares.shareMany(
      equipmentIds: ['mask'],
      diverIds: ['owner'],
      actingDiverId: 'wife',
    );
  });

  tearDown(tearDownTestDatabase);

  Future<Set<String>> tombstones(String entityType) async => {
    for (final r in await db.select(db.deletionLog).get())
      if (r.entityType == entityType) r.recordId,
  };

  test(
    'deleting the sharee drops its shares with tombstones; the owner keeps the item',
    () async {
      final wifeShare = (await (db.select(
        db.equipmentShares,
      )..where((t) => t.diverId.equals('wife'))).getSingle()).id;
      await DiverRepository().deleteDiverWithReassignment('wife');
      expect(
        await (db.select(
          db.equipment,
        )..where((t) => t.id.equals('bcd'))).getSingleOrNull(),
        isNotNull,
      );
      expect(await db.select(db.equipmentShares).get(), isEmpty);
      expect(await tombstones('equipmentShares'), contains(wifeShare));
    },
  );

  test(
    'the owner item keeps its shared event with the sharee nulled',
    () async {
      await DiverRepository().deleteDiverWithReassignment('wife');
      final events = await (db.select(
        db.equipmentOwnershipEvents,
      )..where((t) => t.equipmentId.equals('bcd'))).get();
      expect(events, hasLength(1));
      expect(events.single.toDiverId, isNull);
      expect(events.single.fromDiverId, 'owner');
    },
  );

  test(
    'the deleted diver own items take their events with tombstones',
    () async {
      final maskEvent = (await (db.select(
        db.equipmentOwnershipEvents,
      )..where((t) => t.equipmentId.equals('mask'))).getSingle()).id;
      await DiverRepository().deleteDiverWithReassignment('wife');
      expect(await tombstones('equipmentOwnershipEvents'), contains(maskEvent));
    },
  );
}
