import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// A gear item's sitting dismisses its condition findings (issue #4527,
/// phase 3): logged as a dive's safety findings are, under the item, with
/// only the dismissal recorded, and a revert of it reaching other devices
/// through the item's clock.
void main() {
  late AppDatabase db;
  late ChangeLogRevertService service;
  final repository = ChangeLogRepository();
  var clock = 5000;

  /// A sitting on the item, as the save service labels it.
  Future<String> inSitting(Future<void> Function() body) async {
    late String operationId;
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.manual,
      label: 'record_edit:equipment:g1:conditionFindings',
      body: () async {
        operationId = ChangeLogScope.currentOperationId!;
        await body();
      },
    );
    return operationId;
  }

  Future<void> dismiss() => db.customStatement(
    "UPDATE equipment_findings SET dismissed_at = 7000 WHERE id = 'f1'",
  );

  Future<Object?> cell(String sql) async =>
      (await db.customSelect(sql).getSingleOrNull())?.data.values.single;

  setUp(() async {
    db = await setUpTestDatabase();
    clock = 5000;
    SyncClock.instance.configure(nodeId: 'node-test', now: () => clock++);
    service = ChangeLogRevertService(afterDiveWrites: (_) {});
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, status, purchase_currency, '
      'notes, is_active, created_at, updated_at) VALUES '
      "('g1', 'Apex', 'regulator', 'active', 'USD', '', 1, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_findings (id, equipment_id, rule_id, severity, '
      'value, evidence_fingerprint, engine_version, created_at) VALUES '
      "('f1', 'g1', 'incidentLinked', 'info', 1.0, 'fp', 1, 0)",
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

  test('a dismissal in a sitting records dismissed_at only, under its '
      'item', () async {
    await inSitting(dismiss);
    await repository.settleAll();

    final event = (await logEvents(db)).single;
    expect(event['table_name'], 'equipment_findings');
    expect(event['action'], 'U');
    expect(event['root_table'], 'equipment');
    expect(event['root_id'], 'g1');
    final fields = await logFields(db, event['id']! as int);
    expect(fields, {'dismissed_at': (null, 7000)});
  });

  test('a dismissal outside any operation records nothing', () async {
    await dismiss();

    expect(await logEvents(db), isEmpty);
  });

  test('a recompute rewriting severity in a sitting records nothing', () async {
    await inSitting(
      () => db.customStatement(
        "UPDATE equipment_findings SET value = 3.0, severity = 'warning', "
        "engine_version = 2 WHERE id = 'f1'",
      ),
    );

    expect(await logEvents(db), isEmpty);
  });

  test('a recompute delete in a sitting is dropped while the item '
      'lives', () async {
    await inSitting(
      () =>
          db.customStatement("DELETE FROM equipment_findings WHERE id = 'f1'"),
    );
    await repository.settleAll();

    expect(await logEvents(db), isEmpty);
  });

  test('reverting a sitting\'s dismissal restores it, and reverting the '
      'revert dismisses again', () async {
    final sitting = await inSitting(dismiss);
    await repository.settleAll();

    final revert = await service.execute(await service.planOperation(sitting));
    await repository.settleAll();
    expect(
      await cell("SELECT dismissed_at FROM equipment_findings WHERE id = 'f1'"),
      isNull,
    );

    await service.execute(await service.planOperation(revert.operationId!));
    expect(
      await cell("SELECT dismissed_at FROM equipment_findings WHERE id = 'f1'"),
      7000,
    );
  });

  test('deleting the item keeps its findings\' delete copies, and restoring '
      'it brings the dismissal back', () async {
    await dismiss();
    late String deletion;
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.manual,
      body: () async {
        deletion = ChangeLogScope.currentOperationId!;
        await db.customStatement("DELETE FROM equipment WHERE id = 'g1'");
      },
    );
    await repository.settleAll();
    expect(
      await cell("SELECT COUNT(*) FROM equipment_findings WHERE id = 'f1'"),
      0,
    );

    await service.execute(await service.planOperation(deletion));

    expect(
      await cell("SELECT dismissed_at FROM equipment_findings WHERE id = 'f1'"),
      7000,
    );
  });

  // A finding has no clock of its own: an incremental export selects it by
  // its item's, so a revert that marked only the finding would never leave
  // this device.
  group('a reverted dismissal reaches other devices', () {
    Future<String?> itemHlc() async =>
        await cell("SELECT hlc FROM equipment WHERE id = 'g1'") as String?;

    test('its item is marked pending', () async {
      final sitting = await inSitting(dismiss);
      await repository.settleAll();
      await SyncRepository().clearPendingRecords();

      await service.execute(await service.planOperation(sitting));

      final pending = await SyncRepository().getPendingRecords();
      expect(
        pending.map((r) => (r.entityType, r.recordId)),
        contains(('equipment', 'g1')),
      );
    });

    test(
      'an incremental export after the revert carries the finding',
      () async {
        final sitting = await inSitting(dismiss);
        await repository.settleAll();
        await SyncRepository().markRecordPending(
          entityType: 'equipment',
          recordId: 'g1',
          localUpdatedAt: clock,
        );
        final watermark = await itemHlc();
        expect(watermark, isNotNull);

        await service.execute(await service.planOperation(sitting));

        final since = await SyncDataSerializer().exportChangeset(
          deviceId: 'dev',
          hlcWatermark: watermark,
          deletions: const [],
        );
        final finding = since.data.equipmentFindings.singleWhere(
          (r) => r['id'] == 'f1',
        );
        expect(finding['dismissedAt'], isNull);
      },
    );
  });
}
