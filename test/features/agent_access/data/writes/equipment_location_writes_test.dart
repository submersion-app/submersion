import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Places gear is kept, and the moves between them, as the gear location
/// sheet records them: a place any move names is archived, never deleted.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<String> place(Map<String, Object?> fields) async => (await h.run([
    createOp('equipment_locations', fields),
  ])).created.single.id;

  Map<String, Object?> move(String? locationId, String at) => {
    'equipment_id': 'reg',
    'location_id': locationId,
    'moved_at': at,
    'note': 'Annual check',
  };

  Future<String?> currentPlace() async =>
      (await EquipmentLocationMoveRepository().getCurrentLocationIds())['reg'];

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Regulator',
            type: 'regulator',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('a place is created, renamed, archived and deleted', () async {
    final id = await place({'name': ' Garage ', 'kind': 'storage'});
    expect((await h.one('equipment_locations', id))!['name'], 'Garage');

    await h.run([
      updateOp('equipment_locations', id, {'name': 'Shed'}),
    ]);
    await h.run([
      updateOp('equipment_locations', id, {'is_archived': true}),
    ]);
    final doc = (await h.one('equipment_locations', id))!;
    expect(doc['name'], 'Shed');
    expect(doc['is_archived'], isTrue);

    await h.run([deleteOp('equipment_locations', id)]);
    expect(await h.one('equipment_locations', id), isNull);
  });

  Future<void> links() async {
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion.insert(
            id: 'shop',
            name: 'Reef Shop',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'bud',
            name: 'Bud',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
  }

  // The place dialog keeps a link only while the kind holds it.
  test('a kind change clears the link the new kind does not hold', () async {
    await links();
    final id = await place({
      'name': 'Reef Shop',
      'kind': 'diveCenter',
      'dive_center_id': 'shop',
    });

    final plan = await h.preview([
      updateOp('equipment_locations', id, {'kind': 'storage'}),
    ]);
    final center = plan.items.single.fields['dive_center_id']!;
    expect(
      [center.oldValue, center.newValue, center.indirect],
      ['shop', null, true],
    );
    await h.apply(plan);

    expect((await h.one('equipment_locations', id))!['dive_center_id'], isNull);
  });

  test('a link the kind does not hold is refused', () async {
    await links();

    final plan = await h.preview([
      createOp('equipment_locations', {
        'name': 'Shelf',
        'kind': 'storage',
        'dive_center_id': 'shop',
      }),
      createOp('equipment_locations', {
        'name': 'Shop',
        'kind': 'diveCenter',
        'buddy_id': 'bud',
      }),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });

  test('a person place names its buddy', () async {
    await links();

    final id = await place({
      'name': 'Bud',
      'kind': 'person',
      'buddy_id': 'bud',
    });

    expect((await h.one('equipment_locations', id))!['buddy_id'], 'bud');
  });

  test('a place a move names cannot be deleted', () async {
    final id = await place({'name': 'Shop', 'kind': 'serviceShop'});
    await h.run([
      createOp('equipment_location_moves', move(id, '2026-03-01T10:00:00Z')),
    ]);

    final plan = await h.preview([deleteOp('equipment_locations', id)]);

    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
    expect(plan.items.single.block!.detail, contains('archive'));
  });

  test('a move to a place the set deletes is refused', () async {
    final id = await place({'name': 'Shop', 'kind': 'serviceShop'});

    final plan = await h.preview([
      createOp('equipment_location_moves', move(id, '2026-03-01T10:00:00Z')),
      deleteOp('equipment_locations', id),
    ]);

    expect(plan.items.first.block!.reason, BlockReason.referenceDeleted);
    expect(plan.items.last.block, isNull);
  });

  test('a place whose only move goes elsewhere in the set can go', () async {
    final shop = await place({'name': 'Shop', 'kind': 'serviceShop'});
    final home = await place({'name': 'Home', 'kind': 'storage'});
    final moveId = (await h.run([
      createOp('equipment_location_moves', move(shop, '2026-03-01T10:00:00Z')),
    ])).created.single.id;

    final plan = await h.preview([
      updateOp('equipment_location_moves', moveId, {'location_id': home}),
      deleteOp('equipment_locations', shop),
    ]);

    expect(plan.items.last.block, isNull);
  });

  test('a place whose only move goes earlier in the set can go', () async {
    final id = await place({'name': 'Shop', 'kind': 'serviceShop'});
    final moveId = (await h.run([
      createOp('equipment_location_moves', move(id, '2026-03-01T10:00:00Z')),
    ])).created.single.id;

    final plan = await h.preview([
      deleteOp('equipment_location_moves', moveId),
      deleteOp('equipment_locations', id),
    ]);

    expect(plan.items.last.block, isNull);
  });

  // Archived places leave the move sheet's picker.
  test('a move to an archived place is blocked', () async {
    final id = await place({
      'name': 'Old shed',
      'kind': 'storage',
      'is_archived': true,
    });

    final plan = await h.preview([
      createOp('equipment_location_moves', move(id, '2026-03-01T10:00:00Z')),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  test(
    'a move is recorded, edited and deleted, and the place follows',
    () async {
      final shop = await place({'name': 'Shop', 'kind': 'serviceShop'});
      final home = await place({'name': 'Home', 'kind': 'storage'});

      final id = (await h.run([
        createOp(
          'equipment_location_moves',
          move(shop, '2026-03-01T10:00:00Z'),
        ),
      ])).created.single.id;
      expect(await currentPlace(), shop);

      await h.run([
        updateOp('equipment_location_moves', id, {'location_id': home}),
      ]);
      expect(await currentPlace(), home);
      final doc = (await h.one('equipment_location_moves', id))!;
      expect(doc['moved_at'], '2026-03-01T10:00:00.000Z');
      expect(doc['note'], 'Annual check');

      await h.run([deleteOp('equipment_location_moves', id)]);
      expect(await currentPlace(), isNull);
    },
  );

  test('a move to another profile\'s place is blocked', () async {
    await db
        .into(db.equipmentLocations)
        .insert(
          EquipmentLocationsCompanion.insert(
            id: 'theirs',
            name: 'Their shed',
            kind: const Value('storage'),
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverB),
          ),
        );

    final plan = await h.preview([
      createOp(
        'equipment_location_moves',
        move('theirs', '2026-03-01T10:00:00Z'),
      ),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.otherProfileReference);
  });
}
