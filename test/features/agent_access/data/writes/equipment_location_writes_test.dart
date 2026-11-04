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

  test('a place a move names cannot be deleted', () async {
    final id = await place({'name': 'Shop', 'kind': 'serviceShop'});
    await h.run([
      createOp('equipment_location_moves', move(id, '2026-03-01T10:00:00Z')),
    ]);

    final plan = await h.preview([deleteOp('equipment_locations', id)]);

    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
    expect(plan.items.single.block!.detail, contains('archive'));
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
