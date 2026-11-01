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

  group('saved dive center link', () {
    setUp(() async {
      for (final id in ['reef', 'bay']) {
        await db
            .into(db.diveCenters)
            .insert(
              DiveCentersCompanion.insert(
                id: id,
                name: id,
                createdAt: 1,
                updatedAt: 1,
              ),
            );
      }
    });

    Future<EquipmentLocation> linked() => repo.createLocation(
      diverId: 'me',
      name: 'Reef locker',
      kind: EquipmentLocationKind.diveCenter,
      diveCenterId: 'reef',
    );

    test('createLocation stores the link', () async {
      final place = await linked();
      expect(place.diveCenterId, 'reef');
    });

    test('a new place has no link by default', () async {
      final place = await repo.createLocation(
        diverId: 'me',
        name: 'Garage',
        kind: EquipmentLocationKind.storage,
      );
      expect(place.diveCenterId, isNull);
    });

    test('updateLocation can move and clear the link', () async {
      final place = await linked();
      await repo.updateLocation(place.copyWith(diveCenterId: 'bay'));
      expect((await repo.getLocation(place.id))!.diveCenterId, 'bay');
      await repo.updateLocation(place.copyWith(clearDiveCenterId: true));
      expect((await repo.getLocation(place.id))!.diveCenterId, isNull);
    });

    test('renaming keeps the link', () async {
      final place = await linked();
      await repo.updateLocation(place.copyWith(name: 'Shelf 3'));
      final saved = (await repo.getLocation(place.id))!;
      expect(saved.name, 'Shelf 3');
      expect(saved.diveCenterId, 'reef');
    });

    test('archiving keeps the link', () async {
      final place = await linked();
      await repo.setArchived(place.id, archived: true);
      expect((await repo.getLocation(place.id))!.diveCenterId, 'reef');
    });

    test('deleting the center row keeps the place, unlinked', () async {
      final place = await linked();
      await (db.delete(db.diveCenters)..where((t) => t.id.equals('reef'))).go();
      final saved = (await repo.getLocation(place.id))!;
      expect(saved.name, 'Reef locker');
      expect(saved.kind, EquipmentLocationKind.diveCenter);
      expect(saved.diveCenterId, isNull);
    });
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

  group('buddy link (issue #3790)', () {
    Future<void> buddy(String id) => db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(id: id, name: id, createdAt: 1, updatedAt: 1),
        );

    setUp(() async {
      await buddy('anna');
      await buddy('sam');
    });

    Future<EquipmentLocation> place(
      String name, {
      String? buddyId = 'anna',
      EquipmentLocationKind kind = EquipmentLocationKind.person,
    }) => repo.createLocation(
      diverId: 'me',
      name: name,
      kind: kind,
      buddyId: buddyId,
    );

    test('create, update and clear the buddy link', () async {
      final created = await place('Anna');
      expect(created.buddyId, 'anna');

      await repo.updateLocation(created.copyWith(buddyId: 'sam'));
      expect((await repo.getLocation(created.id))!.buddyId, 'sam');

      await repo.updateLocation(created.copyWith(clearBuddyId: true));
      expect((await repo.getLocation(created.id))!.buddyId, isNull);
    });

    test('findOrCreateForBuddy reuses the linked active place', () async {
      final linked = await place('Anna at home');
      final found = await repo.findOrCreateForBuddy(
        diverId: 'me',
        buddyId: 'anna',
        name: 'Anna',
      );
      expect(found.id, linked.id);
      expect(await repo.getLocations(diverId: 'me'), hasLength(1));
    });

    test('findOrCreateForBuddy prefers the most recently updated of several, '
        'whatever their names', () async {
      final older = await place('A place');
      final newer = await place('Z place');
      Future<void> stamp(String id, int at) =>
          (db.update(db.equipmentLocations)..where((t) => t.id.equals(id)))
              .write(EquipmentLocationsCompanion(updatedAt: Value(at)));
      await stamp(older.id, 10);
      await stamp(newer.id, 20);
      expect(
        (await repo.findOrCreateForBuddy(
          diverId: 'me',
          buddyId: 'anna',
          name: 'Anna',
        )).id,
        newer.id,
      );
      await stamp(older.id, 30);
      expect(
        (await repo.findOrCreateForBuddy(
          diverId: 'me',
          buddyId: 'anna',
          name: 'Anna',
        )).id,
        older.id,
      );
    });

    test('findOrCreateForBuddy skips an archived link and creates a Person '
        'place named after the buddy', () async {
      final archived = await place('Old');
      await repo.setArchived(archived.id, archived: true);
      final created = await repo.findOrCreateForBuddy(
        diverId: 'me',
        buddyId: 'anna',
        name: 'Anna Lindqvist',
      );
      expect(created.id, isNot(archived.id));
      expect(created.name, 'Anna Lindqvist');
      expect(created.kind, EquipmentLocationKind.person);
      expect(created.buddyId, 'anna');
      expect(created.diverId, 'me');
      expect((await repo.getLocation(archived.id))!.isArchived, isTrue);
    });

    test(
      'findOrCreateForBuddy ignores a linked place of another kind',
      () async {
        final other = await place('Retyped', kind: EquipmentLocationKind.other);
        final created = await repo.findOrCreateForBuddy(
          diverId: 'me',
          buddyId: 'anna',
          name: 'Anna',
        );
        expect(created.id, isNot(other.id));
      },
    );

    test('findOrCreateForBuddy leaves another buddy\'s place alone', () async {
      final sams = await place('Sam', buddyId: 'sam');
      final created = await repo.findOrCreateForBuddy(
        diverId: 'me',
        buddyId: 'anna',
        name: 'Anna',
      );
      expect(created.id, isNot(sams.id));
    });
  });
}
