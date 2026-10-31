import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ChangeLogRevertService service;
  final repository = ChangeLogRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    service = ChangeLogRevertService();
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await SyncRepository().clearPendingRecords();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  Future<int> lastEventId() async {
    await repository.settleAll();
    return (await logEvents(db)).last['id']! as int;
  }

  Future<String?> notes() async {
    final row = await db
        .customSelect("SELECT notes FROM dives WHERE id = 'dive'")
        .getSingle();
    return row.data['notes'] as String?;
  }

  Future<Set<String>> pending() async => {
    for (final r in await SyncRepository().getPendingRecords())
      '${r.entityType}:${r.recordId}',
  };

  Future<void> edit(String value) =>
      db.customStatement("UPDATE dives SET notes = '$value' WHERE id = 'dive'");

  test('reverting a field restores it and logs a revert operation', () async {
    await edit('Current');
    final event = await lastEventId();
    final original = (await logEvents(db)).last['operation_id']! as String;

    final plan = await service.planField(event, 'notes');
    final result = await service.execute(plan);

    expect(await notes(), 'Calm');
    expect(result.reverted, 1);
    await repository.settleAll();
    final operations = await db.select(db.changeLogOperations).get();
    final revert = operations.singleWhere((o) => o.source == 'revert');
    expect(revert.revertOfId, original);
    expect(result.operationId, revert.id);
    expect(
      operations.singleWhere((o) => o.id == original).revertedById,
      revert.id,
    );
  });

  test('a revert stamps a fresh clock, never the logged one', () async {
    await db.customStatement("UPDATE dives SET hlc = 'old-clock'");
    await edit('Current');
    final event = await lastEventId();

    await service.execute(await service.planField(event, 'notes'));

    final row = await db
        .customSelect("SELECT hlc, updated_at FROM dives WHERE id = 'dive'")
        .getSingle();
    expect(row.data['hlc'], isNotNull);
    expect(row.data['hlc'], isNot('old-clock'));
    expect(row.data['updated_at'], greaterThan(0));
    expect(await pending(), contains('dives:dive'));
  });

  test('changed since is reported with all three values', () async {
    await edit('Current');
    final event = await lastEventId();
    await edit('Later');

    final plan = await service.planField(event, 'notes');

    expect(plan.hasChangedSince, isTrue);
    final item = plan.items.single;
    expect(item.changedSince, isTrue);
    expect(item.logged, 'Current');
    expect(item.current, 'Later');
    expect(item.target, 'Calm');
  });

  test('skipping changed since keeps that field', () async {
    await edit('Current');
    final event = await lastEventId();
    await edit('Later');

    final result = await service.execute(
      await service.planField(event, 'notes'),
      includeChangedSince: false,
    );

    expect(await notes(), 'Later');
    expect(result.reverted, 0);
    expect(result.kept, 1);
  });

  test('a value already back leaves nothing to revert', () async {
    await edit('Current');
    final event = await lastEventId();
    await edit('Calm');

    final plan = await service.planField(event, 'notes');

    expect(plan.items, isEmpty);
  });

  test('two edits in one entry revert to the first old value', () async {
    await edit('One');
    await edit('Two');
    await repository.settleAll();
    final operation = (await logEvents(db)).last['operation_id']! as String;

    final plan = await service.planOperation(operation);

    expect(plan.items, hasLength(1));
    expect(plan.hasChangedSince, isFalse);
    await service.execute(plan);
    expect(await notes(), 'Calm');
  });

  test('a child revert marks the child, not the parent', () async {
    await db.customStatement(
      "UPDATE dive_tanks SET start_pressure = 200 WHERE id = 'tank'",
    );
    final event = await lastEventId();
    await SyncRepository().clearPendingRecords();

    await service.execute(await service.planEvent(event));

    final row = await db
        .customSelect("SELECT start_pressure, hlc FROM dive_tanks")
        .getSingle();
    expect(row.data['start_pressure'], isNull);
    expect(row.data['hlc'], isNotNull);
    expect(await pending(), {'diveTanks:tank'});
  });

  test('a fact group column stamps its own clock', () async {
    await db.customStatement(
      'INSERT INTO diver_settings (id, diver_id, created_at, updated_at) '
      "VALUES ('s1', 'me', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO change_log_events (operation_id, table_name, record_id, '
      "action, changed_at, schema_version, settled) VALUES ('op', "
      "'diver_settings', 's1', 'U', 1, ${AppDatabase.currentSchemaVersion}, 1)",
    );
    final event = (await logEvents(db)).last['id']! as int;
    await db.customStatement(
      'INSERT INTO change_log_fields (event_id, column_name, old_value, '
      "new_value) VALUES (?, 'dive_list_sort', 'old', NULL)",
      [event],
    );

    await service.execute(await service.planField(event, 'dive_list_sort'));

    final row = await db
        .customSelect(
          'SELECT dive_list_sort, list_arrangement_hlc FROM diver_settings',
        )
        .getSingle();
    expect(row.data['dive_list_sort'], 'old');
    expect(row.data['list_arrangement_hlc'], isNotNull);
  });

  test('a composite key record reverts', () async {
    await db.customStatement(
      'INSERT INTO equipment (id, diver_id, name, type, created_at, '
      "updated_at) VALUES ('gear', 'me', 'Reg', 'regulator', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('dive', 'gear')",
    );
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement(
      "UPDATE dive_equipment SET via_equipment_id = 'gear'",
    );
    final event = await lastEventId();

    await service.execute(await service.planEvent(event));

    final row = await db
        .customSelect('SELECT via_equipment_id FROM dive_equipment')
        .getSingle();
    expect(row.data['via_equipment_id'], isNull);
    expect(await pending(), contains('diveEquipment:dive|gear'));
  });

  test('a settings key reverts', () async {
    await db.customStatement(
      'INSERT INTO settings (key, value, updated_at) '
      "VALUES ('share_new_records_by_default', 'false', 0)",
    );
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement("UPDATE settings SET value = 'true'");
    final event = await lastEventId();

    await service.execute(await service.planEvent(event));

    final row = await db.customSelect('SELECT value FROM settings').getSingle();
    expect(row.data['value'], 'false');
  });

  test('a record that has gone is blocked', () async {
    await edit('Current');
    final event = await lastEventId();
    await db.customStatement("DELETE FROM dives WHERE id = 'dive'");

    final plan = await service.planField(event, 'notes');

    expect(plan.items.single.block, ChangeLogBlock.recordGone);
    final result = await service.execute(plan);
    expect(result.reverted, 0);
    expect(result.kept, 1);
  });

  test('a dropped column is blocked', () async {
    await edit('Current');
    final event = await lastEventId();
    await db.customStatement(
      'INSERT INTO change_log_fields (event_id, column_name, old_value, '
      "new_value) VALUES (?, 'retired_column', 'a', 'b')",
      [event],
    );

    final plan = await service.planField(event, 'retired_column');

    expect(plan.items.single.block, ChangeLogBlock.columnGone);
  });

  test('a rewritten column is blocked', () async {
    await edit('Current');
    final event = await lastEventId();
    final strict = ChangeLogRevertService(
      rewrittenColumns: {'dives.notes': AppDatabase.currentSchemaVersion + 1},
    );

    final plan = await strict.planField(event, 'notes');

    expect(plan.items.single.block, ChangeLogBlock.rewritten);
  });

  test('a revert can be reverted', () async {
    await edit('Current');
    final event = await lastEventId();
    final result = await service.execute(
      await service.planField(event, 'notes'),
    );
    expect(await notes(), 'Calm');
    await repository.settleAll();

    await service.execute(await service.planOperation(result.operationId!));

    expect(await notes(), 'Current');
  });

  test('a failure rolls back every field', () async {
    await db.customStatement(
      "UPDATE dives SET notes = 'Current', max_depth = 30 WHERE id = 'dive'",
    );
    final event = await lastEventId();
    await db.customStatement(
      'INSERT INTO change_log_fields (event_id, column_name, old_value, '
      "new_value) VALUES (?, 'dive_date_time', NULL, 1000)",
      [event],
    );

    final plan = await service.planEvent(event);

    await expectLater(service.execute(plan), throwsA(anything));
    expect(await notes(), 'Current');
  });

  test('a revert waits for a running sync', () async {
    await edit('Current');
    final event = await lastEventId();
    final plan = await service.planField(event, 'notes');
    final release = Completer<void>();
    final sync = SyncCoordinator.run(() => release.future);

    final revert = service.execute(plan);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await notes(), 'Current');

    release.complete();
    await sync;
    await revert;
    expect(await notes(), 'Calm');
  });

  test('a scoped original stays linked through its revert', () async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.rule,
      body: () => edit('Ruled'),
    );
    await repository.settleAll();
    final original = (await logEvents(db)).last['operation_id']! as String;

    await service.execute(await service.planOperation(original));

    expect(await notes(), 'Calm');
    final row = await (db.select(
      db.changeLogOperations,
    )..where((o) => o.id.equals(original))).getSingle();
    expect(row.revertedById, isNotNull);
  });
}
