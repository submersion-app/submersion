import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/built_ins/hidden_built_ins_codec.dart';
import 'package:submersion/core/constants/enums.dart' show EquipmentType;
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Service clocks, as an item's clocks card keeps them: one clock per type,
/// a type that fits the item and that its diver can see, nothing for gear
/// not bought yet, and a baseline the diver picks.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<void> gear(
    String id, {
    String type = 'drysuit',
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
          status: Value(status),
          isActive: Value(active),
        ),
      );

  Future<String> kind({
    String owner = kDiverA,
    List<String> types = const ['drysuit'],
    int? days = 180,
  }) async => (await (db.into(db.serviceKinds)).insertReturning(
    ServiceKindsCompanion.insert(
      id: 'kind-$owner-${types.join()}-$days',
      name: 'Seals $owner',
      applicableTypes: Value('[${types.map((t) => '"$t"').join(',')}]'),
      defaultIntervalDays: Value(days),
      diverId: Value(owner),
      createdAt: t,
      updatedAt: t,
    ),
  )).id;

  Map<String, Object?> clock(String item, String kindId) => {
    'equipment_id': item,
    'service_kind_id': kindId,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await gear('suit');
  });
  tearDown(() => tearDownTestDatabase());

  test('a clock is added, given a baseline, paused and removed', () async {
    final seals = await kind();
    final id = (await h.run([
      createOp('service_schedules', clock('suit', seals)),
    ])).created.single.id;

    await h.run([
      updateOp('service_schedules', id, {
        'anchor_date': '2026-01-15',
        'interval_days': 365,
        'enabled': false,
      }),
    ]);
    final row = await (db.select(
      db.serviceSchedules,
    )..where((s) => s.id.equals(id))).getSingle();
    expect(
      DateTime.fromMillisecondsSinceEpoch(row.anchorDate!),
      DateTime(2026, 1, 15),
    );
    // A baseline the diver picks is stamped, so older records stay behind.
    expect(row.anchorSetAt, isNotNull);
    expect(row.intervalDays, 365);
    expect(row.enabled, isFalse);

    await h.run([deleteOp('service_schedules', id)]);
    expect(await h.one('service_schedules', id), isNull);
  });

  test('one clock per type, in a set and against a stored one', () async {
    final seals = await kind();

    final twice = await h.preview([
      createOp('service_schedules', clock('suit', seals)),
      createOp('service_schedules', clock('suit', seals)),
    ]);
    expect(twice.items.last.block!.reason, BlockReason.duplicateRecord);

    await h.apply(
      await h.preview([createOp('service_schedules', clock('suit', seals))]),
    );
    final again = await h.preview([
      createOp('service_schedules', clock('suit', seals)),
    ]);
    expect(again.items.single.block!.reason, BlockReason.duplicateRecord);
  });

  test('a type the clocks card would not offer is refused', () async {
    await gear('wish', status: 'wanted', active: false);
    final forFins = await kind(types: const ['fins']);
    final theirs = await kind(owner: kDiverB);
    final noInterval = await kind(days: null);
    final hidden = (await ServiceKindRepository().getAllKinds())
        .firstWhere((k) => k.isBuiltIn && k.appliesTo(EquipmentType.drysuit))
        .id;
    await db
        .into(db.diverSettings)
        .insertOnConflictUpdate(
          DiverSettingsCompanion.insert(
            id: 'settings-a',
            diverId: kDiverA,
            createdAt: t,
            updatedAt: t,
            hiddenBuiltInIds: Value(
              encodeHiddenBuiltIns({
                BuiltInCatalog.serviceKinds.key: {hidden},
              }),
            ),
          ),
        );
    final seals = await kind();

    final plan = await h.preview([
      createOp('service_schedules', clock('suit', forFins)),
      createOp('service_schedules', clock('suit', theirs)),
      createOp('service_schedules', clock('suit', noInterval)),
      createOp('service_schedules', clock('suit', hidden)),
      createOp('service_schedules', clock('wish', seals)),
      createOp('service_schedules', {
        ...clock('suit', seals),
        'anchor_date': '2999-01-01',
      }),
    ]);

    expect(
      [for (final item in plan.items) item.block?.detail ?? ''],
      [
        contains('not for a drysuit'),
        contains('another profile'),
        contains('no interval'),
        contains('hidden'),
        contains('not bought yet'),
        contains('1950-01-01'),
      ],
    );
  });

  test('a clock keeps its type and its item', () async {
    final seals = await kind();
    final other = await kind(days: 90);
    final id = (await h.run([
      createOp('service_schedules', clock('suit', seals)),
    ])).created.single.id;

    final plan = await h.preview([
      updateOp('service_schedules', id, {'service_kind_id': other}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('a clock change re-arms its item\'s reminders', () async {
    final asked = <String>[];
    final watched = ChildWriteHarness(
      db,
      catalog: (repositories) => WriteCatalog(
        repositories,
        refreshReminders: (itemId) async => asked.add(itemId),
      ),
    );
    final seals = await kind();
    final id = (await watched.run([
      createOp('service_schedules', clock('suit', seals)),
    ])).created.single.id;
    await watched.run([
      updateOp('service_schedules', id, {'interval_days': 90}),
    ]);

    expect(asked, ['suit', 'suit']);
  });
}
