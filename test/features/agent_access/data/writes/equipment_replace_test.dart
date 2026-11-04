import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart' show EquipmentType;
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Replacing a fitted part, as the children card's Replace does: a new part
/// takes the old one's place and spec, and the old one is retired.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<void> gear(
    String id,
    String type, {
    String? parent,
    String status = 'active',
    bool active = true,
  }) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Gear $id',
          type: type,
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
          parentEquipmentId: Value(parent),
          status: Value(status),
          isActive: Value(active),
        ),
      );

  Map<String, Object?> replacing(
    String id, [
    Map<String, Object?> more = const {},
  ]) => {'replaces_equipment_id': id, ...more};

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await gear('ccr', 'rebreather');
    await gear('cell1', 'o2Cell', parent: 'ccr');
  });
  tearDown(() => tearDownTestDatabase());

  test('a fitted part is replaced in its place', () async {
    final clocks = await ServiceScheduleRepository().autoAttachKindsFor(
      type: EquipmentType.o2Cell,
      diverId: kDiverA,
    );
    final plan = await h.preview([createOp('equipment', replacing('cell1'))]);
    expect(plan.items.single.block, isNull);
    expect(plan.items.single.alsoChanges, {'equipment': 1});
    expect(plan.items.single.alsoCreates, {
      if (clocks.isNotEmpty) 'service_schedules': clocks.length,
    });

    final id = (await h.apply(plan)).created.single.id;

    final fresh = (await h.one('equipment', id))!;
    expect(fresh['parent_equipment_id'], 'ccr');
    expect(fresh['type'], 'o2Cell');
    expect(fresh['name'], 'Gear cell1');
    final old = (await h.one('equipment', 'cell1'))!;
    expect(old['status'], 'retired');
  });

  test('only a fitted part can be replaced', () async {
    await gear('loose', 'o2Cell');
    await gear(
      'spent',
      'o2Cell',
      parent: 'ccr',
      status: 'retired',
      active: false,
    );

    final plan = await h.preview([
      createOp('equipment', replacing('loose')),
      createOp('equipment', replacing('spent')),
    ]);
    final later = await h.preview([
      updateOp('equipment', 'cell1', {'status': 'retired'}),
      createOp('equipment', replacing('cell1')),
    ]);

    for (final item in [...plan.items, later.items.last]) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });

  test('a replacement names only the part it replaces', () async {
    final plan = await h.preview([
      createOp('equipment', replacing('cell1', {'name': 'New cell'})),
      createOp('equipment', {'brand': 'Analox'}),
      updateOp('equipment', 'cell1', {'replaces_equipment_id': 'ccr'}),
    ]);

    expect(
      [for (final item in plan.items) item.block?.reason],
      [
        BlockReason.invalidValue,
        BlockReason.missingField,
        BlockReason.invalidValue,
      ],
    );
  });
}
