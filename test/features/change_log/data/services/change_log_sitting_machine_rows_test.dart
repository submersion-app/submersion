import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// An editing sitting records the machine rows it changes, so its History
/// entry reverts every one (issue #4527): readings moved between cylinders,
/// and a dismissed safety finding, of which only the dismissal is recorded.
void main() {
  late AppDatabase db;
  late ChangeLogRevertService service;
  final repository = ChangeLogRepository();

  /// A sitting on the dive, as the save service labels it.
  Future<String> inSitting(Future<void> Function() body) async {
    late String operationId;
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.manual,
      label: 'record_edit:dives:dive:safetyReview,tanks',
      body: () async {
        operationId = ChangeLogScope.currentOperationId!;
        await body();
      },
    );
    return operationId;
  }

  Future<void> moveSeries() => db.customStatement(
    "UPDATE tank_pressure_series SET tank_id = 'b' WHERE id = 'series'",
  );

  Future<void> dismiss() => db.customStatement(
    "UPDATE dive_safety_findings SET dismissed_at = 7000 WHERE id = 'finding'",
  );

  Future<Object?> cell(String sql) async =>
      (await db.customSelect(sql).getSingle()).data.values.single;

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    service = ChangeLogRevertService(afterDiveWrites: (_) {});
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me');
    for (final tank in ['a', 'b']) {
      await db.customStatement(
        'INSERT INTO dive_tanks (id, dive_id) VALUES (?, ?)',
        [tank, 'dive'],
      );
    }
    await db.customStatement(
      'INSERT INTO tank_pressure_series (id, dive_id, tank_id, sample_count, '
      'start_timestamp, end_timestamp, codec_version, samples, created_at, '
      "updated_at) VALUES ('series', 'dive', 'a', 2, 0, 60, 1, ?, 0, 0)",
      [
        Uint8List.fromList([1, 2, 3]),
      ],
    );
    await db.customStatement(
      'INSERT INTO dive_safety_findings (id, dive_id, rule_id, severity, '
      'value, engine_version, created_at) VALUES '
      "('finding', 'dive', 'fast_ascent', 'warning', 12.0, 1, 0)",
    );
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await SyncRepository().clearPendingRecords();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  test('a series moved in a sitting records tank_id old and new', () async {
    await inSitting(moveSeries);

    final events = await logEvents(db);
    expect(events.single['table_name'], 'tank_pressure_series');
    expect(events.single['action'], 'U');
    final fields = await logFields(db, events.single['id']! as int);
    expect(fields, {'tank_id': ('a', 'b')});
  });

  test('a finding dismissed in a sitting records dismissed_at only', () async {
    await inSitting(dismiss);

    final events = await logEvents(db);
    expect(events.single['table_name'], 'dive_safety_findings');
    expect(events.single['action'], 'U');
    final fields = await logFields(db, events.single['id']! as int);
    expect(fields, {'dismissed_at': (null, 7000)});
  });

  test('a finding dismissed outside any operation records nothing', () async {
    await dismiss();

    expect(await logEvents(db), isEmpty);
  });

  test('a review rewriting a finding\'s value and severity in a sitting '
      'records nothing', () async {
    await inSitting(
      () => db.customStatement(
        "UPDATE dive_safety_findings SET value = 15.0, severity = 'alert', "
        "engine_version = 2 WHERE id = 'finding'",
      ),
    );

    expect(await logEvents(db), isEmpty);
  });

  test('a finding a review deletes in a sitting is dropped while the dive '
      'lives', () async {
    await inSitting(
      () => db.customStatement(
        "DELETE FROM dive_safety_findings WHERE id = 'finding'",
      ),
    );
    await repository.settleAll();

    expect(await logEvents(db), isEmpty);
  });

  group('a sitting that only dismissed a finding, reverted', () {
    Future<String> revertOf(String operationId) async {
      final result = await service.execute(
        await service.planOperation(operationId),
      );
      await repository.settleAll();
      return result.operationId!;
    }

    Future<Map<String, Object?>?> operationRow(String id) async =>
        (await db
                .customSelect(
                  'SELECT * FROM change_log_operations WHERE id = ?',
                  variables: [Variable<String>(id)],
                )
                .getSingleOrNull())
            ?.data;

    test('leaves a revert entry the sitting points at', () async {
      final sitting = await inSitting(dismiss);
      await repository.settleAll();

      final revert = await revertOf(sitting);

      expect(await operationRow(revert), isNotNull);
      expect((await operationRow(sitting))!['reverted_by_id'], revert);
      expect(
        await cell(
          "SELECT dismissed_at FROM dive_safety_findings WHERE id = 'finding'",
        ),
        isNull,
      );
    });

    test('and reverting that revert dismisses it again', () async {
      final sitting = await inSitting(dismiss);
      await repository.settleAll();
      final revert = await revertOf(sitting);

      await revertOf(revert);

      expect(
        await cell(
          "SELECT dismissed_at FROM dive_safety_findings WHERE id = 'finding'",
        ),
        7000,
      );
    });
  });

  test('both survive settling while the dive lives', () async {
    await inSitting(() async {
      await moveSeries();
      await dismiss();
    });
    await repository.settleAll();

    final events = await logEvents(db);
    expect(
      {for (final e in events) (e['table_name'], e['action'], e['settled'])},
      {('tank_pressure_series', 'U', 1), ('dive_safety_findings', 'U', 1)},
    );
  });

  test(
    'reverting the sitting puts the series and the dismissal back',
    () async {
      final operationId = await inSitting(() async {
        await moveSeries();
        await dismiss();
      });
      await repository.settleAll();

      await service.execute(await service.planOperation(operationId));

      expect(
        await cell(
          "SELECT tank_id FROM tank_pressure_series WHERE id = 'series'",
        ),
        'a',
      );
      expect(
        await cell(
          "SELECT dismissed_at FROM dive_safety_findings WHERE id = 'finding'",
        ),
        isNull,
      );
    },
  );

  // Readings move between cylinders in pairs, so one series going back on
  // its own would leave both on one cylinder.
  test('a moved series cannot be reverted on its own', () async {
    await inSitting(moveSeries);
    await repository.settleAll();
    final event = (await logEvents(db)).single;

    expect(
      () => service.planField(event['id']! as int, 'tank_id'),
      throwsArgumentError,
    );
  });
}
