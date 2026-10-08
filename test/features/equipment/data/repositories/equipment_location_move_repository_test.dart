import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentLocationMoveRepository moves;

  Future<void> item(String id, {String? parent, String status = 'active'}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          createdAt: 1,
          updatedAt: 1,
          diverId: const Value('me'),
          parentEquipmentId: Value(parent),
          status: Value(status),
        ),
      );

  Future<void> place(String id) => db
      .into(db.equipmentLocations)
      .insert(
        EquipmentLocationsCompanion.insert(
          id: id,
          name: id,
          createdAt: 1,
          updatedAt: 1,
          diverId: const Value('me'),
        ),
      );

  Future<void> component(String parent, String child) => db
      .into(db.equipmentComponents)
      .insert(
        EquipmentComponentsCompanion.insert(
          id: 'c-$child',
          parentEquipmentId: parent,
          componentEquipmentId: child,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    moves = EquipmentLocationMoveRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await item('reg');
    await place('garage');
    await place('shop');
  });

  tearDown(tearDownTestDatabase);

  test('the newest move is the current location; an older backdated move '
      'does not win', () async {
    await moves.recordMoves(
      equipmentIds: ['reg'],
      locationId: 'shop',
      movedAt: DateTime(2026, 9, 3),
    );
    await moves.recordMoves(
      equipmentIds: ['reg'],
      locationId: 'garage',
      movedAt: DateTime(2026, 8, 1),
    );
    expect(await moves.getCurrentLocationIds(), {'reg': 'shop'});
    expect(
      [for (final m in await moves.getMovesFor('reg')) m.locationId],
      ['shop', 'garage'],
    );
  });

  test('an item with no moves is absent from the current locations', () async {
    await item('bcd');
    await moves.recordMoves(
      equipmentIds: ['reg'],
      locationId: 'shop',
      movedAt: DateTime(2026, 9, 3),
    );
    expect(await moves.getCurrentLocationIds(), {'reg': 'shop'});
  });

  Future<void> rawMove(String id, String placeId, int createdAt) => db
      .into(db.equipmentLocationMoves)
      .insert(
        EquipmentLocationMovesCompanion.insert(
          id: id,
          equipmentId: 'reg',
          locationId: Value(placeId),
          movedAt: 1000,
          createdAt: createdAt,
        ),
      );

  // Inserted in the order a naive reverse walk of the (equipment_id,
  // moved_at) index would get wrong, so only the created_at and id keys can
  // make these pass.
  test('ties on moved_at break by created_at', () async {
    await rawMove('m1', 'garage', 200);
    await rawMove('m2', 'shop', 100);
    expect(await moves.getCurrentLocationIds(), {'reg': 'garage'});
    expect((await moves.getMovesFor('reg')).first.locationId, 'garage');
  });

  test('ties on moved_at and created_at break by id', () async {
    await rawMove('b', 'garage', 100);
    await rawMove('a', 'shop', 100);
    expect(await moves.getCurrentLocationIds(), {'reg': 'garage'});
    expect((await moves.getMovesFor('reg')).first.locationId, 'garage');
  });

  test('a cleared move reads as no location; deleting it restores the '
      'prior place', () async {
    await moves.recordMoves(
      equipmentIds: ['reg'],
      locationId: 'shop',
      movedAt: DateTime(2026, 9, 1),
    );
    final cleared = await moves.recordMoves(
      equipmentIds: ['reg'],
      locationId: null,
      movedAt: DateTime(2026, 9, 2),
    );
    expect(await moves.getCurrentLocationIds(), {'reg': null});
    await moves.deleteMove(cleared.single.id);
    expect(await moves.getCurrentLocationIds(), {'reg': 'shop'});
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.map((t) => t.recordId), contains(cleared.single.id));
  });

  test('a move whose place was deleted reads as no location', () async {
    await moves.recordMoves(
      equipmentIds: ['reg'],
      locationId: 'shop',
      movedAt: DateTime(2026, 9, 1),
    );
    // A peer deleted the place: the foreign key nulls the move's place.
    await (db.delete(
      db.equipmentLocations,
    )..where((t) => t.id.equals('shop'))).go();
    expect(await moves.getCurrentLocationIds(), {'reg': null});
  });

  test('recordMoves writes one pending move per distinct item', () async {
    await item('bcd');
    final written = await moves.recordMoves(
      equipmentIds: ['reg', 'bcd', 'reg'],
      locationId: 'garage',
      movedAt: DateTime(2026, 9, 1),
      note: '  annual ',
    );
    expect(written.map((m) => m.equipmentId), unorderedEquals(['reg', 'bcd']));
    expect(written.every((m) => m.note == 'annual'), isTrue);
    final pending = await db.select(db.syncRecords).get();
    expect(
      pending
          .where((r) => r.entityType == 'equipmentLocationMoves')
          .map((r) => r.recordId),
      unorderedEquals(written.map((m) => m.id)),
    );
  });

  test('updateMove recomputes the current location and restamps', () async {
    final m = (await moves.recordMoves(
      equipmentIds: ['reg'],
      locationId: 'shop',
      movedAt: DateTime(2026, 9, 1),
    )).single;
    final before = await (db.select(
      db.equipmentLocationMoves,
    )..where((t) => t.id.equals(m.id))).getSingle();
    await moves.updateMove(m.copyWith(locationId: 'garage', note: 'fixed'));
    expect(await moves.getCurrentLocationIds(), {'reg': 'garage'});
    expect((await moves.getMovesFor('reg')).single.note, 'fixed');
    final after = await (db.select(
      db.equipmentLocationMoves,
    )..where((t) => t.id.equals(m.id))).getSingle();
    expect(after.hlc, isNotNull);
    expect(after.hlc!.compareTo(before.hlc!), greaterThan(0));
  });

  test('deleteForEquipment deletes and tombstones the item\'s moves', () async {
    await moves.recordMoves(
      equipmentIds: ['reg'],
      locationId: 'shop',
      movedAt: DateTime(2026, 9, 1),
    );
    await db.transaction(() => moves.deleteForEquipment('reg'));
    expect(await moves.getMovesFor('reg'), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where((r) => r.entityType == 'equipmentLocationMoves'),
      isNotEmpty,
    );
  });

  test('partsOf excludes the given ids and retired parts', () async {
    await item('first');
    await item('second');
    await item('cell', parent: 'second');
    await item('oldCell', parent: 'second', status: 'retired');
    await item('sold', parent: 'reg', status: 'sold');
    await component('reg', 'first');
    await component('reg', 'second');
    final parts = await moves.partsOf(['reg']);
    expect(parts.keys.toSet(), {'first', 'second', 'cell'});
    expect(parts['cell'], EquipmentStatus.active);
    expect((await moves.partsOf(['reg', 'first'])).keys.toSet(), {
      'second',
      'cell',
    });
  });

  test(
    'partsOf walks through a retired part to a live one inside it',
    () async {
      await item('oldFirst', parent: 'reg', status: 'retired');
      await item('battery', parent: 'oldFirst');
      expect((await moves.partsOf(['reg'])).keys.toSet(), {'battery'});
    },
  );

  test('setStatusForMany writes status and keeps the items active', () async {
    await item('bcd');
    await EquipmentRepository().setStatusForMany([
      'reg',
      'bcd',
    ], EquipmentStatus.inService);
    final rows = await db.select(db.equipment).get();
    expect(
      {for (final r in rows) r.id: r.status},
      {'reg': 'inService', 'bcd': 'inService'},
    );
    expect(rows.every((r) => r.isActive), isTrue);
  });

  test('deleting an item through the repository removes its moves', () async {
    await moves.recordMoves(
      equipmentIds: ['reg'],
      locationId: 'shop',
      movedAt: DateTime(2026, 9, 1),
    );
    await EquipmentRepository().deleteEquipment('reg');
    expect(await db.select(db.equipmentLocationMoves).get(), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where((r) => r.entityType == 'equipmentLocationMoves'),
      isNotEmpty,
    );
  });

  test('partsOf leaves out wanted parts, which are not owned yet', () async {
    await item('wantedCell', parent: 'reg', status: 'wanted');
    await item('cell', parent: 'reg');
    expect((await moves.partsOf(['reg'])).keys.toSet(), {'cell'});
  });
}
