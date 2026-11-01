import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../helpers/test_database.dart';

const _now = 1767225600000;

db.DivePlanSeriesCompanion _series(String id, String diveId) =>
    db.DivePlanSeriesCompanion.insert(
      id: id,
      name: 'Saturday on the wall',
      followedDiveId: Value(diveId),
      createdAt: _now,
      updatedAt: _now,
      hlc: const Value('0001-test-hlc'),
    );

db.DivePlansCompanion _plan(String id, String seriesId, int index) =>
    db.DivePlansCompanion.insert(
      id: id,
      name: 'Saturday on the wall',
      seriesId: Value(seriesId),
      seriesIndex: Value(index),
      diveName: Value('Dive ${index + 1}'),
      fixedStart: Value(index == 0),
      settingOverrides: const Value('deco,tanks'),
      createdAt: _now,
      updatedAt: _now,
      hlc: const Value('0001-test-hlc'),
    );

void main() {
  group('Dive plan series sync round trip (FK ON)', () {
    late db.AppDatabase database;

    setUp(() async {
      database = await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('a series and its plans survive export, JSON and apply', () async {
      final dive = await DiveRepository().createDive(
        Dive(id: 'dive-1', diveNumber: 1, dateTime: DateTime(2026, 1, 1)),
      );
      await database
          .into(database.divePlanSeries)
          .insert(_series('series-1', dive.id));
      await database
          .into(database.divePlans)
          .insert(_plan('plan-2', 'series-1', 1));
      await database
          .into(database.divePlanTanks)
          .insert(
            db.DivePlanTanksCompanion.insert(
              id: 'tank-2',
              planId: 'plan-2',
              startPressure: const Value(150),
              sourceTankId: const Value('logged-tank-1'),
              startPressurePinned: const Value(true),
              createdAt: _now,
              updatedAt: _now,
              hlc: const Value('0001-test-hlc'),
            ),
          );

      final serializer = SyncDataSerializer();
      final syncRepository = SyncRepository();
      final payload = await serializer.exportData(
        deviceId: await syncRepository.getDeviceId(),
        lastSyncTimestamp: null,
        deletions: await syncRepository.getAllDeletions(),
      );
      expect(payload.data.divePlanSeries, hasLength(1));

      final decoded = SyncData.fromJson(
        jsonDecode(jsonEncode(payload.data.toJson())) as Map<String, dynamic>,
      );
      final series = decoded.divePlanSeries.single;
      expect(series['name'], 'Saturday on the wall');
      expect(series['followedDiveId'], 'dive-1');
      final plan = decoded.divePlans.single;
      expect(plan['seriesId'], 'series-1');
      expect(plan['seriesIndex'], 1);
      expect(plan['diveName'], 'Dive 2');
      expect(plan['fixedStart'], isFalse);
      expect(plan['settingOverrides'], 'deco,tanks');
      final tank = decoded.divePlanTanks.single;
      expect(tank['sourceTankId'], 'logged-tank-1');
      expect(tank['startPressurePinned'], isTrue);

      // Apply into a second FK-ON database with the followed dive present,
      // the series before the plan that references it.
      final db2 = db.AppDatabase(NativeDatabase.memory());
      addTearDown(() => db2.close());
      DatabaseService.instance.resetForTesting();
      DatabaseService.instance.setTestDatabase(db2);
      await db2.customStatement('PRAGMA foreign_keys = ON');
      await DiveRepository().createDive(
        Dive(id: 'dive-1', diveNumber: 1, dateTime: DateTime(2026, 1, 1)),
      );
      final serializer2 = SyncDataSerializer();
      await serializer2.upsertRecord('divePlanSeries', series);
      await serializer2.upsertRecord('divePlans', plan);
      await serializer2.upsertRecord('divePlanTanks', tank);

      final seriesRows = await db2.select(db2.divePlanSeries).get();
      expect(seriesRows.single.followedDiveId, 'dive-1');
      final planRow = await db2.select(db2.divePlans).getSingle();
      expect(planRow.seriesId, 'series-1');
      expect(planRow.seriesIndex, 1);
      final tankRow = await db2.select(db2.divePlanTanks).getSingle();
      expect(tankRow.sourceTankId, 'logged-tank-1');
      expect(tankRow.startPressurePinned, isTrue);

      expect(
        (await serializer2.fetchRecord('divePlanSeries', 'series-1'))?['name'],
        'Saturday on the wall',
      );
      expect(
        (await serializer2.fetchRecords('divePlanSeries', ['series-1'])).keys,
        ['series-1'],
      );

      // Record ids round-trip through deleteRecord.
      final ids = await serializer2.recordIdsFor('divePlanSeries');
      expect(ids, contains('series-1'));
      await serializer2.deleteRecord('divePlanTanks', 'tank-2');
      await serializer2.deleteRecord('divePlans', 'plan-2');
      await serializer2.deleteRecord('divePlanSeries', 'series-1');
      expect(await db2.select(db2.divePlanSeries).get(), isEmpty);

      // The batch path applies the same row.
      await serializer2.upsertRecords('divePlanSeries', [series]);
      expect(await db2.select(db2.divePlanSeries).get(), hasLength(1));
    });
  });
}
