import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Gas switches as the dive editor shows them, written through its writer.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<void> computer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value('Computer $id'),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> gasSwitch(
    String id,
    int t,
    String tankId, {
    String? computerId,
    double? depth,
  }) => db
      .into(db.gasSwitches)
      .insert(
        GasSwitchesCompanion(
          id: Value(id),
          diveId: const Value('d3'),
          timestamp: Value(t),
          tankId: Value(tankId),
          depth: Value(depth),
          computerId: Value(computerId),
          createdAt: const Value(0),
        ),
      );

  Future<GasSwitche?> row(String id) => (db.select(
    db.gasSwitches,
  )..where((s) => s.id.equals(id))).getSingleOrNull();

  Map<String, Object?> update(String id, Map<String, Object?> fields) =>
      updateOp('gas_switches', id, fields);

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await computer('c1');
    await computer('c2');
    // Two cylinders, a profile that is 30 m deep at ten minutes, and c1 as
    // its primary computer.
    await DiveRepository().createDive(
      domain.Dive(
        id: 'd3',
        diverId: kDiverA,
        name: 'Dive d3',
        dateTime: DateTime.utc(2024, 3, 14, 9, 30),
        computerId: 'c1',
        tanks: const [
          domain.DiveTank(id: 't-back', name: 'Back gas'),
          domain.DiveTank(id: 't-deco', name: 'Deco'),
        ],
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: 600, depth: 30),
          domain.DiveProfilePoint(timestamp: 1200, depth: 6),
        ],
      ),
    );
    // createDive leaves the primary computer to the import that sets it.
    await (db.update(db.dives)..where((d) => d.id.equals('d3'))).write(
      const DivesCompanion(computerId: Value('c1')),
    );
    await gasSwitch('g1', 1200, 't-deco', computerId: 'c1', depth: 6);
    await gasSwitch('g2', 1100, 't-deco', computerId: 'c2', depth: 9);
  });
  tearDown(() => tearDownTestDatabase());

  test('a new switch is written by the editor\'s writer', () async {
    final result = await h.run([
      createOp('gas_switches', {
        'dive_id': 'd3',
        't_s': 900,
        'tank_id': 't-deco',
        'depth_m': 21.0,
      }),
    ]);

    final created = (await row(result.created.single.id))!;
    expect(created.timestamp, 900);
    expect(created.depth, 21.0);
    expect(created.computerId, isNull);
    final dive = await (db.select(
      db.dives,
    )..where((d) => d.id.equals('d3'))).getSingle();
    expect(dive.gasSwitchesEdited, isTrue);
    // Another computer's switch is untouched.
    expect((await row('g2'))!.timestamp, 1100);
  });

  test(
    'a moved switch takes the profile depth, and the plan says so',
    () async {
      final plan = await h.preview([
        update('g1', {'t_s': 600}),
      ]);

      final change = plan.items.single.fields['depth_m']!;
      expect(change.newValue, 30.0);
      expect(change.indirect, isTrue);

      await h.apply(plan);
      final moved = (await row('g1'))!;
      expect(moved.timestamp, 600);
      expect(moved.depth, 30.0);
      expect(moved.computerId, 'c1');
    },
  );

  test('a depth the change names wins over the profile', () async {
    await h.run([
      update('g1', {'t_s': 600, 'depth_m': 28.0}),
    ]);

    expect((await row('g1'))!.depth, 28.0);
  });

  test('another computer\'s switch is blocked', () async {
    final plan = await h.preview([deleteOp('gas_switches', 'g2')]);

    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
  });

  test('a cylinder of another dive is blocked', () async {
    await db
        .into(db.diveTanks)
        .insert(
          const DiveTanksCompanion(id: Value('t-other'), diveId: Value('d1')),
        );

    final plan = await h.preview([
      update('g1', {'tank_id': 't-other'}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('a dive with one cylinder has no switches to change', () async {
    await db
        .into(db.diveTanks)
        .insert(const DiveTanksCompanion(id: Value('t1'), diveId: Value('d1')));

    final plan = await h.preview([
      createOp('gas_switches', {'dive_id': 'd1', 't_s': 60, 'tank_id': 't1'}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
  });

  // A mode the app does not know reads as open circuit everywhere else, so
  // the dive editor shows its switches; the plan must not throw on it.
  test('a dive mode the app does not know reads as open circuit', () async {
    await (db.update(db.dives)..where((d) => d.id.equals('d3'))).write(
      const DivesCompanion(diveMode: Value('freedive')),
    );

    final plan = await h.preview([
      update('g1', {'t_s': 600}),
    ]);

    expect(plan.items.single.block, isNull);
  });

  test('a time past the end of the profile is blocked', () async {
    final switched = await h.preview([
      createOp('gas_switches', {
        'dive_id': 'd3',
        't_s': 5000,
        'tank_id': 't-deco',
      }),
    ]);
    final annotated = await h.preview([
      createOp('dive_events', {
        'dive_id': 'd3',
        't_s': 5000,
        'description': 'Off the end',
      }),
    ]);

    for (final plan in [switched, annotated]) {
      expect(plan.items.single.block!.reason, BlockReason.invalidValue);
      expect(plan.items.single.block!.detail, contains('1200'));
    }
  });

  test('a delete removes the switch and a revert restores it', () async {
    final result = await h.run([deleteOp('gas_switches', 'g1')]);
    expect(await row('g1'), isNull);
    expect(h.refreshed.single, {'d3'});

    await h.revert(result);

    expect((await row('g1'))!.timestamp, 1200);
  });
}
