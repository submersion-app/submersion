import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// Device-local idempotency ledger for [StartupMaintenanceTask]s.
///
/// A task records the entity ids it has handled (namespaced by an opaque
/// task name); its `pendingWork()` excludes ledgered ids so the backlog
/// converges to zero. Reused by every maintenance task with no schema change.
class MaintenanceLedgerRepository {
  final AppDatabase? _injected;

  /// [db] is injected in tests; production defaults to the live singleton so a
  /// restore that swaps the database is picked up (mirrors [MediaRepository]).
  MaintenanceLedgerRepository([AppDatabase? db]) : _injected = db;

  AppDatabase get _db => _injected ?? DatabaseService.instance.database;

  /// Number of entities recorded for [taskName].
  Future<int> countProcessed(String taskName) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM maintenance_processed '
          'WHERE task_name = ?',
          variables: [Variable.withString(taskName)],
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// Entity ids recorded for [taskName].
  Future<Set<String>> processedEntityIds(String taskName) async {
    final rows = await _db
        .customSelect(
          'SELECT entity_id FROM maintenance_processed WHERE task_name = ?',
          variables: [Variable.withString(taskName)],
        )
        .get();
    return rows.map((r) => r.read<String>('entity_id')).toSet();
  }

  /// Records that [taskName] has handled each id in [entityIds]. Idempotent on
  /// the (task_name, entity_id) primary key.
  Future<void> markProcessed(
    String taskName,
    Iterable<String> entityIds, {
    DateTime? at,
  }) async {
    final ids = entityIds.toList();
    if (ids.isEmpty) return;
    final millis = (at ?? DateTime.now()).millisecondsSinceEpoch;

    MaintenanceProcessedCompanion row(String id) =>
        MaintenanceProcessedCompanion.insert(
          taskName: taskName,
          entityId: id,
          attemptedAt: millis,
        );

    // Common case (the backfill marks one item at a time): a single insert
    // avoids the batch/transaction wrapper.
    if (ids.length == 1) {
      await _db
          .into(_db.maintenanceProcessed)
          .insert(row(ids.first), mode: InsertMode.insertOrIgnore);
      return;
    }

    await _db.batch((batch) {
      for (final id in ids) {
        batch.insert(
          _db.maintenanceProcessed,
          row(id),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }
}
