import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/families/tank_writes.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Tanks are records of their own that belong to a dive: they take its
/// owner, its version stands in for theirs, and they stay on it.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<void> tank(
    String id, {
    String diveId = 'd1',
    double o2 = 21,
    double he = 0,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value(id),
          diveId: Value(diveId),
          o2Percent: Value(o2),
          hePercent: Value(he),
          startPressure: const Value(200),
          endPressure: const Value(50),
          tankName: Value('Tank $id'),
        ),
      );

  Future<void> gasSwitch(String id, String tankId) => db
      .into(db.gasSwitches)
      .insert(
        GasSwitchesCompanion(
          id: Value(id),
          diveId: const Value('d1'),
          timestamp: const Value(60),
          tankId: Value(tankId),
          createdAt: const Value(0),
        ),
      );

  Map<String, Object?> create(Map<String, Object?> fields, {String? diver}) =>
      createOp('dive_tanks', fields, diver: diver);

  Map<String, Object?> update(String id, Map<String, Object?> fields) =>
      updateOp('dive_tanks', id, fields);

  PlanBlock? blockOf(WritePlan plan) => plan.items.single.block;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await tank('t1');
  });
  tearDown(() => tearDownTestDatabase());

  group('preview', () {
    test('a new tank takes the owner of its dive', () async {
      final plan = await h.preview([
        create({'dive_id': 'd2', 'o2_fraction': 0.32}),
      ]);

      final item = plan.items.single;
      expect(item.block, isNull);
      expect(item.diverId, kDiverB);
      expect(item.parentId, 'd2');
      expect(plan.markers.single.table, 'dives');
      expect(plan.markers.single.id, 'd2');
    });

    test('a profile other than the dive\'s is blocked', () async {
      final plan = await h.preview([
        create({'dive_id': 'd2'}, diver: kDiverA),
      ]);

      expect(blockOf(plan)!.reason, BlockReason.invalidValue);
      expect(blockOf(plan)!.detail, contains(kDiverB));
    });

    test('a dive that does not exist is blocked', () async {
      final plan = await h.preview([
        create({'dive_id': 'nope'}),
      ]);

      expect(blockOf(plan)!.reason, BlockReason.unknownReference);
    });

    test('a new tank must name its dive', () async {
      final plan = await h.preview([
        create({'o2_fraction': 0.32}),
      ]);

      expect(blockOf(plan)!.reason, BlockReason.missingField);
      expect(blockOf(plan)!.detail, contains('dive_id'));
    });

    test('a tank stays on its dive', () async {
      final moved = await h.preview([
        update('t1', {'dive_id': 'd2'}),
      ]);
      final same = await h.preview([
        update('t1', {'dive_id': 'd1', 'volume_l': 12}),
      ]);

      expect(blockOf(moved)!.reason, BlockReason.notPermitted);
      expect(same.items.single.block, isNull);
      expect(same.items.single.fields.keys, ['volume_l']);
    });

    test('a tank of a dive the set deletes is blocked', () async {
      final changed = await h.preview([
        deleteOp('dives', 'd1'),
        update('t1', {'volume_l': 12}),
      ]);
      final deleted = await h.preview([
        deleteOp('dives', 'd1'),
        deleteOp('dive_tanks', 't1'),
      ]);
      final created = await h.preview([
        deleteOp('dives', 'd1'),
        create({'dive_id': 'd1'}),
      ]);

      for (final plan in [changed, deleted, created]) {
        expect(plan.items.last.block!.reason, BlockReason.referenceDeleted);
      }
    });

    test('an update is marked by its dive and owned by its owner', () async {
      final plan = await h.preview([
        update('t1', {'volume_l': 12}),
      ]);

      final item = plan.items.single;
      expect(item.diverId, kDiverA);
      expect(item.parentId, 'd1');
      expect(item.title, 'Tank t1');
      final marker = plan.markers.single;
      expect(marker.table, 'dives');
      expect(marker.id, 'd1');
      expect(marker.updatedAt, kSeedTime);
    });

    test('oxygen and helium cannot make up more than the whole', () async {
      await tank('t2', o2: 90);

      final both = await h.preview([
        update('t1', {'o2_fraction': 0.5, 'he_fraction': 0.6}),
      ]);
      final heOnly = await h.preview([
        update('t2', {'he_fraction': 0.2}),
      ]);
      final trimix = await h.preview([
        update('t1', {'o2_fraction': 0.18, 'he_fraction': 0.45}),
      ]);

      expect(blockOf(both)!.reason, BlockReason.invalidValue);
      expect(blockOf(heOnly)!.reason, BlockReason.invalidValue);
      expect(trimix.items.single.block, isNull);
    });

    test('a delete lists the switches and series it takes', () async {
      await TankPressureSeriesRepository().insertSeries(
        diveId: 'd1',
        tankId: 't1',
        samples: const [TankPressureSample(timestamp: 0, pressure: 200)],
      );
      await gasSwitch('g1', 't1');

      final plan = await h.preview([deleteOp('dive_tanks', 't1')]);

      expect(plan.items.single.reach.parts, {
        'gas_switches': 1,
        'tank_pressure_series': 1,
      });
    });
  });

  group('apply', () {
    test('a create is a tank of air on the dive, after its tanks', () async {
      final result = await h.run([
        create({'dive_id': 'd1', 'volume_l': 11.1}),
      ]);

      final doc = (await h.one('dive_tanks', result.created.single.id))!;
      expect(doc['dive_id'], 'd1');
      expect(doc['o2_fraction'], 0.21);
      expect(doc['he_fraction'], 0.0);
      expect(doc['role'], 'backGas');
      expect(doc['order'], 1);
      expect(doc['volume_l'], 11.1);
      expect(h.refreshed.single, {'d1'});
    });

    test('every field reaches its column', () async {
      const samples = <String, Object?>{
        'name': 'Left stage',
        'volume_l': 7.0,
        'working_pressure_bar': 207.0,
        'start_pressure_bar': 210.0,
        'end_pressure_bar': 90.0,
        'o2_fraction': 0.5,
        'he_fraction': 0.0,
        'role': 'stage',
        'material': 'aluminum',
        'order': 3,
        'preset_name': 'al40',
      };
      expect(
        samples.keys.toSet(),
        TankWrites().fields.keys.toSet().difference({'dive_id'}),
      );

      await h.run([update('t1', samples)]);

      final doc = (await h.one('dive_tanks', 't1'))!;
      for (final MapEntry(:key, :value) in samples.entries) {
        expect(doc[key], value, reason: key);
      }
      expect(h.refreshed.single, {'d1'});
    });

    test('a gas the document writes as a fraction stores cleanly', () async {
      await h.run([
        update('t1', {'o2_fraction': 0.29}),
      ]);

      final row = await (db.select(
        db.diveTanks,
      )..where((r) => r.id.equals('t1'))).getSingle();
      expect(row.o2Percent, 29.0);
    });

    test('a tank changed alone after the preview is stale', () async {
      final plan = await h.preview([
        update('t1', {'volume_l': 12}),
      ]);
      // As a merge would: the row changes and its dive does not.
      await (db.update(db.diveTanks)..where((r) => r.id.equals('t1'))).write(
        const DiveTanksCompanion(startPressure: Value(232)),
      );

      await expectLater(
        h.apply(plan),
        throwsA(
          isA<AgentToolException>().having(
            (e) => e.code,
            'code',
            AgentToolErrorCode.planStale,
          ),
        ),
      );
    });

    test('a revert brings a deleted tank back with its switches', () async {
      await gasSwitch('g1', 't1');

      final result = await h.run([deleteOp('dive_tanks', 't1')]);
      expect(await h.one('dive_tanks', 't1'), isNull);
      expect(await db.select(db.gasSwitches).get(), isEmpty);

      await h.revert(result);

      expect((await h.one('dive_tanks', 't1'))!['name'], 'Tank t1');
      expect(await db.select(db.gasSwitches).get(), hasLength(1));
    });
  });
}
