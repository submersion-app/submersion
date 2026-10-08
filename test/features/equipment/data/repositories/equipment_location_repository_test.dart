import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentLocationRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentLocationRepository();
    const t = 1;
    for (final id in ['me', 'other']) {
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
            id: 'reg',
            name: 'Reg',
            type: 'regulator',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('me'),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('create trims the name, marks it pending and lists it', () async {
    final loc = await repo.createLocation(
      diverId: 'me',
      name: '  Garage bin 2 ',
      kind: EquipmentLocationKind.storage,
    );
    expect(loc.name, 'Garage bin 2');
    expect(loc.kind, EquipmentLocationKind.storage);
    final pending = await db.select(db.syncRecords).get();
    expect(
      pending.where(
        (r) => r.entityType == 'equipmentLocations' && r.recordId == loc.id,
      ),
      isNotEmpty,
    );
    expect((await repo.getLocations(diverId: 'me')).single.id, loc.id);
    expect(await repo.getLocations(diverId: 'other'), isEmpty);
  });

  test('an empty name is rejected', () async {
    await expectLater(
      repo.createLocation(
        diverId: 'me',
        name: '   ',
        kind: EquipmentLocationKind.other,
      ),
      throwsArgumentError,
    );
  });

  test('update renames and rekinds', () async {
    final loc = await repo.createLocation(
      diverId: 'me',
      name: 'Shop',
      kind: EquipmentLocationKind.other,
    );
    await repo.updateLocation(
      loc.copyWith(
        name: "Joe's Scuba",
        kind: EquipmentLocationKind.serviceShop,
      ),
    );
    final read = await repo.getLocation(loc.id);
    expect(read!.name, "Joe's Scuba");
    expect(read.kind, EquipmentLocationKind.serviceShop);
  });

  test('a used place cannot be deleted, only archived', () async {
    final loc = await repo.createLocation(
      diverId: 'me',
      name: 'Shop',
      kind: EquipmentLocationKind.serviceShop,
    );
    await EquipmentLocationMoveRepository().recordMoves(
      equipmentIds: ['reg'],
      locationId: loc.id,
      movedAt: DateTime(2026, 9, 1),
    );
    expect(await repo.isInUse(loc.id), isTrue);
    await expectLater(repo.deleteLocation(loc.id), throwsStateError);
    expect(await repo.getLocation(loc.id), isNotNull);
    await repo.setArchived(loc.id, archived: true);
    expect((await repo.getLocation(loc.id))!.isArchived, isTrue);
    await repo.setArchived(loc.id, archived: false);
    expect((await repo.getLocation(loc.id))!.isArchived, isFalse);
  });

  test('an unused place deletes and tombstones', () async {
    final loc = await repo.createLocation(
      diverId: 'me',
      name: 'Car',
      kind: EquipmentLocationKind.other,
    );
    expect(await repo.isInUse(loc.id), isFalse);
    await repo.deleteLocation(loc.id);
    expect(await repo.getLocation(loc.id), isNull);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where(
        (r) => r.entityType == 'equipmentLocations' && r.recordId == loc.id,
      ),
      isNotEmpty,
    );
  });

  test('findOrCreateByName matches case-insensitively, active first', () async {
    final archived = await repo.createLocation(
      diverId: 'me',
      name: 'Locker',
      kind: EquipmentLocationKind.storage,
    );
    await repo.setArchived(archived.id, archived: true);
    expect(
      (await repo.findOrCreateByName(diverId: 'me', name: 'locker')).id,
      archived.id,
    );
    final active = await repo.createLocation(
      diverId: 'me',
      name: 'LOCKER',
      kind: EquipmentLocationKind.storage,
    );
    expect(
      (await repo.findOrCreateByName(diverId: 'me', name: 'Locker')).id,
      active.id,
    );
    final created = await repo.findOrCreateByName(diverId: 'me', name: 'Boat');
    expect(created.kind, EquipmentLocationKind.other);
    expect(created.diverId, 'me');
  });
}
