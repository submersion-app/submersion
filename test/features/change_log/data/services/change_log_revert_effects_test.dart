import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

class _RecordingCoordinator extends MediaDeletionCoordinator {
  _RecordingCoordinator()
    : super(
        mediaRepository: MediaRepository(),
        queue: () => throw StateError('This test has no media queue'),
      );

  final repaired = <String>[];

  @override
  Future<void> repairRestoredMedia(List<MediaData> rows) async {
    repaired.addAll(rows.map((row) => row.id));
  }
}

void main() {
  late AppDatabase db;
  late _RecordingCoordinator media;
  late ChangeLogRevertService service;
  final repository = ChangeLogRepository();

  Future<int> count(String table, String where) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM $table WHERE $where')
        .getSingle();
    return row.read<int>('c');
  }

  Future<String> newestOperation() async {
    await repository.settleAll();
    final row = await db
        .customSelect(
          'SELECT id FROM change_log_operations '
          'WHERE event_count > 0 ORDER BY last_event_id DESC LIMIT 1',
        )
        .getSingle();
    return row.read<String>('id');
  }

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    media = _RecordingCoordinator();
    service = ChangeLogRevertService(
      afterDiveWrites: (_) {},
      mediaDeletionCoordinator: media,
    );
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await SyncRepository().clearPendingRecords();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  test(
    'a field revert does not close an entry that also added a record',
    () async {
      await db.customStatement("UPDATE dives SET notes = 'Rough'");
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
      final operationId = await newestOperation();
      final notes = (await repository.getEvents(
        operationId,
      )).firstWhere((event) => event.table == 'dives');

      await service.execute(await service.planField(notes.id, 'notes'));

      final operation = await repository.getOperation(operationId);
      expect(operation!.isReverted, isFalse);
    },
  );

  test('restored media has its upload stamps repaired', () async {
    await db.customStatement(
      'INSERT INTO media (id, dive_id, file_path, file_type, created_at, '
      "updated_at) VALUES ('photo', 'dive', '/p.jpg', 'photo', 0, 0)",
    );
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await db.customStatement("DELETE FROM media WHERE id = 'photo'");

    await service.execute(await service.planOperation(await newestOperation()));

    expect(await count('media', "id = 'photo'"), 1);
    expect(media.repaired, ['photo']);
  });

  test('a removed record tombstones what cascades with it', () async {
    await db.customStatement(
      'INSERT INTO equipment (id, diver_id, name, type, created_at, '
      "updated_at) VALUES ('fins', 'me', 'Fins', 'fins', 0, 0)",
    );
    final created = await newestOperation();
    // Past the window that would make the next save part of this entry.
    await db.customStatement(
      'UPDATE change_log_operations SET ended_at = 0 WHERE id = ?',
      [created],
    );
    await db.customStatement(
      'INSERT INTO service_records (id, equipment_id, service_category, '
      "service_date, created_at, updated_at) VALUES ('svc', 'fins', 'annual', "
      '0, 0, 0)',
    );
    await repository.settleAll();

    final plan = await service.planOperation(created);
    expect(plan.hasChangedSince, isTrue);
    await service.execute(plan);

    expect(await count('service_records', "id = 'svc'"), 0);
    expect(
      await count(
        'deletion_log',
        "entity_type = 'serviceRecords' AND record_id = 'svc'",
      ),
      1,
    );
  });

  test('a bulk undo holds the long lease through its transaction', () async {
    await db.customStatement("UPDATE dives SET notes = 'Rough'");
    final plan = await service.planOperation(await newestOperation());
    await probeLease(db);

    await service.execute(plan);

    expect(await probedLease(db), greaterThan(kChangeLogLease));
  });

  test('a delete copy from a dropped table does not stop the rest', () async {
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await db.customStatement("DELETE FROM dive_tanks WHERE id = 'tank'");
    final operationId = await newestOperation();
    await db.customStatement(
      'INSERT INTO change_log_events (operation_id, table_name, record_id, '
      "action, changed_at, schema_version, settled) VALUES (?, 'retired', "
      "'old', 'D', 0, 300, 1)",
      [operationId],
    );

    final plan = await service.planOperation(operationId);
    final retired = plan.items.singleWhere((i) => i.event.table == 'retired');
    expect(retired.block, ChangeLogBlock.columnGone);

    await service.execute(plan);

    expect(await count('dive_tanks', "id = 'tank'"), 1);
  });

  test('a kept record keeps a row that belongs to it mid-way down', () async {
    await db.customStatement(
      'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
      "created_at, updated_at) VALUES ('trip', 'me', 'Reef', 0, 0, 0, 0)",
    );
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    final operationId = await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.bulkEdit,
      body: () async {
        await db.customStatement(
          'INSERT INTO trip_cylinders (id, trip_id, created_at, updated_at) '
          "VALUES ('bottle', 'trip', 0, 0)",
        );
        await db.customStatement(
          'INSERT INTO trip_cylinder_events (id, trip_cylinder_id, kind, '
          "occurred_at, created_at, updated_at) VALUES ('fill', 'bottle', "
          "'fill', 0, 0, 0)",
        );
        return ChangeLogScope.currentOperationId!;
      },
    );
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
    await db.customStatement(
      "UPDATE dive_tanks SET trip_cylinder_id = 'bottle' WHERE id = 'tank'",
    );
    await repository.settleAll();

    await service.execute(await service.planOperation(operationId));

    expect(await count('trip_cylinders', "id = 'bottle'"), 1);
    expect(await count('trip_cylinder_events', "id = 'fill'"), 1);
  });

  test("a merged diver's delete follows the keeper into the log", () async {
    await insertDiver(db, 'dup');
    await insertDive(db, 'dup-dive', diverId: 'dup');
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    await DiverMergeRepository().mergeDivers(
      keeperId: 'me',
      duplicateId: 'dup',
    );
    await repository.settleAll();

    expect(await count('change_log_operations', "diver_id = 'dup'"), 0);
    final feed = await repository.getFeed(
      diverId: 'me',
      filter: const ChangeLogFilter(),
    );
    final events = [
      for (final operation in feed) ...await repository.getEvents(operation.id),
    ];
    expect(
      events.where((e) => e.table == 'divers' && e.recordId == 'dup'),
      isNotEmpty,
    );
  });
}
