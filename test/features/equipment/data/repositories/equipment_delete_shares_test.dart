import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'bcd',
            name: 'bcd',
            type: 'bcd',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('owner'),
          ),
        );
    await EquipmentShareRepository().shareMany(
      equipmentIds: ['bcd'],
      diverIds: ['wife'],
      actingDiverId: 'owner',
    );
  });

  tearDown(tearDownTestDatabase);

  Future<Set<String>> tombstones(String entityType) async => {
    for (final r in await db.select(db.deletionLog).get())
      if (r.entityType == entityType) r.recordId,
  };

  test('deleting an item tombstones its shares and events', () async {
    final shareId = (await db.select(db.equipmentShares).getSingle()).id;
    final eventId =
        (await db.select(db.equipmentOwnershipEvents).getSingle()).id;
    await repo.deleteEquipment('bcd');
    expect(await db.select(db.equipmentShares).get(), isEmpty);
    expect(await tombstones('equipmentShares'), contains(shareId));
    expect(await tombstones('equipmentOwnershipEvents'), contains(eventId));
  });

  test('a sharee cannot delete; the owner can', () async {
    expect(
      await repo.deleteOwnedEquipment('bcd', actingDiverId: 'wife'),
      isFalse,
    );
    expect(await repo.getEquipmentById('bcd'), isNotNull);
    expect(
      await repo.deleteOwnedEquipment('bcd', actingDiverId: 'owner'),
      isTrue,
    );
    expect(await repo.getEquipmentById('bcd'), isNull);
  });

  test('with no diver at all the delete proceeds', () async {
    expect(await repo.deleteOwnedEquipment('bcd', actingDiverId: null), isTrue);
  });
}
