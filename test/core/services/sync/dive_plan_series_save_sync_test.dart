import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/entities/plan_setting_group.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';

import '../../../features/planner/series/series_fixtures.dart';
import '../../../helpers/test_database.dart';

/// A series through the save path and out to another device (issue #3565).
void main() {
  late DivePlanSeriesRepository repo;
  late SyncRepository sync;

  setUp(() async {
    await setUpTestDatabase();
    repo = DivePlanSeriesRepository();
    sync = SyncRepository();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  StoredSeries twoDives({String? followed}) => StoredSeries(
    id: 's1',
    name: 'Reef day',
    followedDiveId: followed,
    dives: [
      StoredSeriesDive(plan: divePlanFromState(seriesDiveState(id: 'a'))),
      StoredSeriesDive(
        plan: divePlanFromState(
          seriesDiveState(id: 'b', surfaceInterval: const Duration(hours: 2)),
        ),
        name: 'Wreck',
        settingOverrides: const {PlanSettingGroup.deco},
        sourceTankIds: const {'b-back': 'a-back'},
        pinnedTankIds: const {'b-stage'},
      ),
    ],
  );

  test('saving marks the series, its dives and their tanks for sync', () async {
    await repo.saveSeries(twoDives());

    final pending = {
      for (final record in await sync.getPendingRecords())
        '${record.entityType}/${record.recordId}',
    };
    expect(
      pending,
      containsAll([
        'divePlanSeries/s1',
        'divePlans/a',
        'divePlans/b',
        'divePlanTanks/b-back',
      ]),
    );
  });

  test('what saving places in a dive leaves in the export', () async {
    await repo.saveSeries(twoDives());

    final payload = await SyncDataSerializer().exportData(
      deviceId: await sync.getDeviceId(),
      lastSyncTimestamp: null,
      deletions: await sync.getAllDeletions(),
    );
    final decoded = SyncData.fromJson(
      jsonDecode(jsonEncode(payload.data.toJson())) as Map<String, dynamic>,
    );

    expect(decoded.divePlanSeries.single['id'], 's1');
    final b = decoded.divePlans.singleWhere((p) => p['id'] == 'b');
    expect(b['seriesId'], 's1');
    expect(b['seriesIndex'], 1);
    expect(b['diveName'], 'Wreck');
    expect(b['settingOverrides'], 'deco');
    final tank = decoded.divePlanTanks.singleWhere((t) => t['id'] == 'b-back');
    expect(tank['sourceTankId'], 'a-back');
    final stage = decoded.divePlanTanks.singleWhere(
      (t) => t['id'] == 'b-stage',
    );
    expect(stage['startPressurePinned'], isTrue);
  });

  test(
    'deleting tombstones the plans and their tanks, then the series',
    () async {
      await repo.saveSeries(twoDives());
      await repo.deleteSeries('s1');

      final deleted = {
        for (final d in await sync.getAllDeletions())
          '${d.entityType}/${d.recordId}',
      };
      expect(
        deleted,
        containsAll([
          'divePlanSeries/s1',
          'divePlans/a',
          'divePlans/b',
          'divePlanTanks/a-back',
          'divePlanTanks/b-back',
        ]),
      );
    },
  );

  group('on another device', () {
    late db.AppDatabase other;
    late SyncDataSerializer serializer;
    late Map<String, dynamic> seriesRow;
    late Map<String, dynamic> planRow;

    setUp(() async {
      await repo.saveSeries(twoDives());
      final local = SyncDataSerializer();
      seriesRow = (await local.fetchRecord('divePlanSeries', 's1'))!;
      planRow = (await local.fetchRecord('divePlans', 'b'))!;

      other = db.AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      DatabaseService.instance.resetForTesting();
      DatabaseService.instance.setTestDatabase(other);
      await other.customStatement('PRAGMA foreign_keys = ON');
      serializer = SyncDataSerializer();
    });

    test(
      'a followed dive can arrive after the series in one payload',
      () async {
        final dive = await DiveRepository().createDive(
          Dive(id: 'd1', diveNumber: 1, dateTime: DateTime.utc(2026, 1, 1)),
        );
        final diveRow = (await serializer.fetchRecord('dives', dive.id))!;
        await other.customStatement("DELETE FROM dives WHERE id = 'd1'");

        await serializer.applyInDeferredFkTransaction(() async {
          await serializer.upsertRecord('divePlanSeries', {
            ...seriesRow,
            'followedDiveId': 'd1',
          });
          await serializer.upsertRecord('dives', diveRow);
        });

        final row = await other.select(other.divePlanSeries).getSingle();
        expect(row.followedDiveId, 'd1');
      },
    );

    test('a series deleted elsewhere frees a dive edited here', () async {
      await serializer.applyInDeferredFkTransaction(() async {
        await serializer.upsertRecord('divePlanSeries', seriesRow);
        await serializer.upsertRecord('divePlans', planRow);
      });

      await serializer.applyInDeferredFkTransaction(() async {
        await serializer.deleteRecord('divePlanSeries', 's1');
        await serializer.repairDanglingForeignKeys();
      });

      final plan = await other.select(other.divePlans).getSingle();
      expect(plan.id, 'b');
      expect(plan.seriesId, isNull);
      expect(await other.select(other.divePlanSeries).get(), isEmpty);
    });
  });
}
