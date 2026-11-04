import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Service types, as the service types page keeps them: a custom one is
/// the diver's to change, a built-in one is the app's, and a delete takes
/// the clocks of that type with it.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<String> created(Map<String, Object?> fields) async =>
      (await h.run([createOp('service_kinds', fields)])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a custom type is created, renamed and deleted', () async {
    final id = await created({
      'name': ' Seal check ',
      'applicable_types': ['drysuit', 'wetsuit'],
      'default_interval_days': 180,
      'exposure_intervals': {'saltHours': 50},
      'default_category': 'inspection',
    });
    final doc = (await h.one('service_kinds', id))!;
    expect(doc['name'], 'Seal check');
    expect(doc['applicable_types'], unorderedEquals(['drysuit', 'wetsuit']));
    expect(doc['exposure_intervals'], {'saltHours': 50.0});
    expect(doc['diver_id'], kDiverA);

    await h.run([
      updateOp('service_kinds', id, {'name': 'Seals'}),
    ]);
    expect((await h.one('service_kinds', id))!['name'], 'Seals');

    await h.run([deleteOp('service_kinds', id)]);
    expect(await h.one('service_kinds', id), isNull);
  });

  test('writing back the intervals a read lists is unchanged', () async {
    final id = await created({
      'name': 'Seal check',
      'exposure_intervals': {'saltHours': 50, 'cycles': 10},
    });

    final plan = await h.preview([
      updateOp('service_kinds', id, {
        'exposure_intervals': {'cycles': 10, 'saltHours': 50.0},
      }),
    ]);

    expect(plan.unchanged.single.id, id);
  });

  test('a delete lists and takes the clocks of its type', () async {
    final id = await created({'name': 'Seal check'});
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'suit',
            name: 'Drysuit',
            type: 'drysuit',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    await ServiceScheduleRepository().createSchedule(
      ServiceSchedule(
        id: 'clock',
        equipmentId: 'suit',
        serviceKindId: id,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    final plan = await h.preview([deleteOp('service_kinds', id)]);
    expect(plan.items.single.reach.parts['service_schedules'], 1);
    await h.apply(plan);

    expect(await h.one('service_schedules', 'clock'), isNull);
  });

  test('a built-in type cannot be changed or deleted', () async {
    final builtIn = (await (db.select(
      db.serviceKinds,
    )..where((k) => k.isBuiltIn.equals(true))).get()).first.id;

    final plan = await h.preview([
      updateOp('service_kinds', builtIn, {'default_interval_days': 30}),
    ]);
    final gone = await h.preview([deleteOp('service_kinds', builtIn)]);

    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
    expect(gone.items.single.block!.reason, BlockReason.notPermitted);
  });

  // The type editor takes counts as whole numbers, and no interval is 0.
  test('a zero interval or a fractional count is refused', () async {
    final plan = await h.preview([
      createOp('service_kinds', {'name': 'A', 'default_interval_days': 0}),
      createOp('service_kinds', {
        'name': 'B',
        'exposure_intervals': {'coldDives': 1.5},
      }),
      createOp('service_kinds', {'name': 'C', 'default_currency': 'euro'}),
    ]);

    for (final item in plan.items) {
      expect(item.block, isNotNull, reason: item.values['name'] as String?);
    }
  });
}
