import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/families/tank_writes.dart';
import 'package:submersion/features/agent_access/data/writes/write_applier.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

class _Allow implements WriteConfirmer {
  @override
  Future<bool> confirm(WriteConfirmation request) async => true;
}

/// Tanks are records of their own that belong to a dive: they take its
/// owner, its version stands in for theirs, and they stay on it.
void main() {
  late AppDatabase db;
  late RecordHarness h;
  late RecordRepositories repositories;
  late WriteCatalog writes;
  late ChangeLogRepository changeLog;
  late List<Set<String>> refreshed;
  const t = kSeedTime;

  Future<void> dive(String id, {String owner = kDiverA}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(owner),
          diveDateTime: 1710408600000,
          createdAt: t,
          updatedAt: t,
        ),
      );

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

  Future<WritePlan> preview(List<Map<String, Object?>> operations) =>
      WritePlanner(
        writes: writes,
        records: RecordCatalog(repositories),
      ).preview(
        db,
        ChangeSet.parse({'label': 'Tanks', 'operations': operations}),
        resolveDiver: (id) async => id ?? kDiverA,
      );

  WriteApplier applier() => WriteApplier(
    catalog: writes,
    changeLog: changeLog,
    confirmer: _Allow(),
    confirmEnabled: () => false,
    afterDiveWrites: (ids) => refreshed.add(ids.toSet()),
    rearmDocuments: (_) async {},
  );

  Map<String, Object?> create(Map<String, Object?> fields, {String? diver}) => {
    'op': 'create',
    'entity': 'dive_tanks',
    'diver_id': ?diver,
    'fields': fields,
  };

  Map<String, Object?> update(String id, Map<String, Object?> fields) => {
    'op': 'update',
    'entity': 'dive_tanks',
    'id': id,
    'fields': fields,
  };

  Map<String, Object?> delete(String entity, String id) => {
    'op': 'delete',
    'entity': entity,
    'id': id,
  };

  PlanBlock? blockOf(WritePlan plan) => plan.items.single.block;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = RecordHarness(db);
    await seedTwoDivers(db);
    repositories = RecordRepositories();
    writes = WriteCatalog(repositories);
    changeLog = ChangeLogRepository();
    refreshed = [];
    await dive('d1');
    await dive('d2', owner: kDiverB);
    await tank('t1');
  });
  tearDown(() => tearDownTestDatabase());

  group('preview', () {
    test('a new tank takes the owner of its dive', () async {
      final plan = await preview([
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
      final plan = await preview([
        create({'dive_id': 'd2'}, diver: kDiverA),
      ]);

      expect(blockOf(plan)!.reason, BlockReason.invalidValue);
      expect(blockOf(plan)!.detail, contains(kDiverB));
    });

    test('a dive that does not exist is blocked', () async {
      final plan = await preview([
        create({'dive_id': 'nope'}),
      ]);

      expect(blockOf(plan)!.reason, BlockReason.unknownReference);
    });

    test('a new tank must name its dive', () async {
      final plan = await preview([
        create({'o2_fraction': 0.32}),
      ]);

      expect(blockOf(plan)!.reason, BlockReason.missingField);
      expect(blockOf(plan)!.detail, contains('dive_id'));
    });

    test('a tank stays on its dive', () async {
      final moved = await preview([
        update('t1', {'dive_id': 'd2'}),
      ]);
      final same = await preview([
        update('t1', {'dive_id': 'd1', 'volume_l': 12}),
      ]);

      expect(blockOf(moved)!.reason, BlockReason.notPermitted);
      expect(same.items.single.block, isNull);
      expect(same.items.single.fields.keys, ['volume_l']);
    });

    test('a tank of a dive the set deletes is blocked', () async {
      final changed = await preview([
        delete('dives', 'd1'),
        update('t1', {'volume_l': 12}),
      ]);
      final deleted = await preview([
        delete('dives', 'd1'),
        delete('dive_tanks', 't1'),
      ]);
      final created = await preview([
        delete('dives', 'd1'),
        create({'dive_id': 'd1'}),
      ]);

      for (final plan in [changed, deleted, created]) {
        expect(plan.items.last.block!.reason, BlockReason.referenceDeleted);
      }
    });

    test('an update is marked by its dive and owned by its owner', () async {
      final plan = await preview([
        update('t1', {'volume_l': 12}),
      ]);

      final item = plan.items.single;
      expect(item.diverId, kDiverA);
      expect(item.parentId, 'd1');
      expect(item.title, 'Tank t1');
      final marker = plan.markers.single;
      expect(marker.table, 'dives');
      expect(marker.id, 'd1');
      expect(marker.updatedAt, t);
    });

    test('oxygen and helium cannot make up more than the whole', () async {
      await tank('t2', o2: 90);

      final both = await preview([
        update('t1', {'o2_fraction': 0.5, 'he_fraction': 0.6}),
      ]);
      final heOnly = await preview([
        update('t2', {'he_fraction': 0.2}),
      ]);
      final trimix = await preview([
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
      await db
          .into(db.gasSwitches)
          .insert(
            const GasSwitchesCompanion(
              id: Value('g1'),
              diveId: Value('d1'),
              timestamp: Value(60),
              tankId: Value('t1'),
              createdAt: Value(0),
            ),
          );

      final plan = await preview([delete('dive_tanks', 't1')]);

      expect(plan.items.single.reach.parts, {
        'gas_switches': 1,
        'tank_pressure_series': 1,
      });
    });
  });

  group('apply', () {
    test('a create is a tank of air on the dive, after its tanks', () async {
      final plan = await preview([
        create({'dive_id': 'd1', 'volume_l': 11.1}),
      ]);

      final result = await applier().apply(db, plan);

      final id = result.created.single.id;
      final doc = (await h.one('dive_tanks', id))!;
      expect(doc['dive_id'], 'd1');
      expect(doc['o2_fraction'], 0.21);
      expect(doc['he_fraction'], 0.0);
      expect(doc['role'], 'backGas');
      expect(doc['order'], 1);
      expect(doc['volume_l'], 11.1);
      expect(refreshed.single, {'d1'});
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

      await applier().apply(db, await preview([update('t1', samples)]));

      final doc = (await h.one('dive_tanks', 't1'))!;
      for (final MapEntry(:key, :value) in samples.entries) {
        expect(doc[key], value, reason: key);
      }
      expect(refreshed.single, {'d1'});
    });

    test('a gas the document writes as a fraction stores cleanly', () async {
      await applier().apply(
        db,
        await preview([
          update('t1', {'o2_fraction': 0.29}),
        ]),
      );

      final row = await (db.select(
        db.diveTanks,
      )..where((r) => r.id.equals('t1'))).getSingle();
      expect(row.o2Percent, 29.0);
    });

    test('a tank changed alone after the preview is stale', () async {
      final plan = await preview([
        update('t1', {'volume_l': 12}),
      ]);
      // As a merge would: the row changes and its dive does not.
      await (db.update(db.diveTanks)..where((r) => r.id.equals('t1'))).write(
        const DiveTanksCompanion(startPressure: Value(232)),
      );

      await expectLater(
        applier().apply(db, plan),
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
      await db
          .into(db.gasSwitches)
          .insert(
            const GasSwitchesCompanion(
              id: Value('g1'),
              diveId: Value('d1'),
              timestamp: Value(60),
              tankId: Value('t1'),
              createdAt: Value(0),
            ),
          );

      final result = await applier().apply(
        db,
        await preview([delete('dive_tanks', 't1')]),
      );
      expect(await h.one('dive_tanks', 't1'), isNull);
      expect(await db.select(db.gasSwitches).get(), isEmpty);

      final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
      await revert.execute(
        await revert.planOperation(result.operations.single.operationId),
      );

      expect((await h.one('dive_tanks', 't1'))!['name'], 'Tank t1');
      expect(await db.select(db.gasSwitches).get(), hasLength(1));
    });
  });
}
