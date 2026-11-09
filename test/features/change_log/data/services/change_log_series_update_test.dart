import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// Updates to series rows are recorded only inside an operation whose label
/// asks for it (issue #4393), so a removal that re-zeroes or promotes a
/// series reverts completely while routine sweeps stay out of the log.
void main() {
  late AppDatabase db;
  late ChangeLogRevertService service;
  final repository = ChangeLogRepository();

  Future<void> forget() async {
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  }

  Future<void> editSeries() => db.customStatement(
    'UPDATE dive_profile_series SET samples = ?, is_primary = 1 '
    "WHERE id = 'series'",
    [
      Uint8List.fromList([9, 9]),
    ],
  );

  Future<Map<String, Object?>> seriesRow() async =>
      (await db
              .customSelect(
                'SELECT samples, is_primary FROM dive_profile_series '
                "WHERE id = 'series'",
              )
              .getSingle())
          .data;

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    service = ChangeLogRevertService(afterDiveWrites: (_) {});
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me');
    await db.customStatement(
      'INSERT INTO dive_profile_series (id, dive_id, sample_count, '
      'start_timestamp, end_timestamp, max_depth, first_depth, last_depth, '
      'codec_version, samples, is_primary, created_at, updated_at) VALUES '
      "('series', 'dive', 2, 0, 60, 10.0, 0.0, 0.0, 1, ?, 0, 0, 0)",
      [
        Uint8List.fromList([1, 2, 3]),
      ],
    );
    await forget();
    await SyncRepository().clearPendingRecords();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  test('a series update outside any operation records nothing', () async {
    await editSeries();

    expect(await logEvents(db), isEmpty);
  });

  test('a series update in a quality repair records nothing', () async {
    await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.qualityRepair,
      body: editSeries,
    );

    expect(await logEvents(db), isEmpty);
  });

  test('a series update in a remove source operation records old and new '
      'values', () async {
    await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.removeSource,
      body: editSeries,
    );

    final events = await logEvents(db);
    expect(events, hasLength(1));
    expect(events.single['table_name'], 'dive_profile_series');
    expect(events.single['action'], 'U');
    final fields = await logFields(db, events.single['id']! as int);
    expect(fields['is_primary'], (0, 1));
    expect(fields['samples']!.$1, [1, 2, 3]);
    expect(fields['samples']!.$2, [9, 9]);
  });

  test(
    'a duplicate cylinder removal records pressure series updates',
    () async {
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'other', diveId: 'dive'));
      await db.customStatement(
        'INSERT INTO tank_pressure_series (id, dive_id, tank_id, sample_count, '
        'start_timestamp, end_timestamp, codec_version, samples, created_at, '
        "updated_at) VALUES ('pressure', 'dive', 'tank', 1, 0, 0, 1, ?, 0, 0)",
        [
          Uint8List.fromList([4]),
        ],
      );
      await forget();

      await ChangeLogScope.bulk(
        db,
        label: ChangeLogLabels.removeDuplicateCylinders,
        body: () => db.customStatement(
          "UPDATE tank_pressure_series SET tank_id = 'other' "
          "WHERE id = 'pressure'",
        ),
      );

      final events = await logEvents(db);
      expect(events.map((e) => (e['table_name'], e['action'])), [
        ('tank_pressure_series', 'U'),
      ]);
    },
  );

  test(
    'an opted-in series update survives settling while its dive lives',
    () async {
      await ChangeLogScope.bulk(
        db,
        label: ChangeLogLabels.removeSource,
        body: editSeries,
      );

      await repository.settleAll();

      final events = await logEvents(db);
      expect(events, hasLength(1));
      expect(events.single['action'], 'U');
    },
  );

  test('an opted-in series delete survives settling while its dive lives, '
      'even with no source to have gone', () async {
    await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.removeSource,
      body: () => db.customStatement(
        "DELETE FROM dive_profile_series WHERE id = 'series'",
      ),
    );

    await repository.settleAll();

    final events = await logEvents(db);
    expect(events.map((e) => e['action']), ['D']);
  });

  test('a series delete in another operation is still dropped while its dive '
      'lives', () async {
    await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.qualityRepair,
      body: () => db.customStatement(
        "DELETE FROM dive_profile_series WHERE id = 'series'",
      ),
    );

    await repository.settleAll();

    expect(await logEvents(db), isEmpty);
  });

  test('revert restores an opted-in samples edit without a changed-since '
      'block', () async {
    String? operationId;
    await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.removeSource,
      body: () async {
        operationId = ChangeLogScope.currentOperationId;
        await editSeries();
      },
    );
    await repository.settleAll();

    final plan = await service.planOperation(operationId!);
    expect(plan.hasChangedSince, isFalse);
    await service.execute(plan);

    final row = await seriesRow();
    expect(row['samples'], [1, 2, 3]);
    expect(row['is_primary'], 0);
  });
}
