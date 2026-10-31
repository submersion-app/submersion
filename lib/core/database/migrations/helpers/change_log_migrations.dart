part of '../app_database_migrations.dart';

/// The per-device change log (issue #3922).
extension ChangeLogMigrations on AppDatabase {
  /// v332: the four log tables, their indexes and the one context row.
  /// Idempotent. Also re-asserted in beforeOpen, which reaches a database
  /// that arrives by restore already at this version.
  Future<void> _assertChangeLogSchema() async {
    final migrator = Migrator(this);
    if (!await _tableExists('change_log_context')) {
      await migrator.createTable(changeLogContext);
    }
    if (!await _tableExists('change_log_operations')) {
      await migrator.createTable(changeLogOperations);
    }
    if (!await _tableExists('change_log_events')) {
      await migrator.createTable(changeLogEvents);
    }
    if (!await _tableExists('change_log_fields')) {
      await migrator.createTable(changeLogFields);
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_change_log_operations_feed '
      'ON change_log_operations (diver_id, last_event_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_change_log_operations_root '
      'ON change_log_operations (root_table, root_id, last_event_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_change_log_operations_order '
      'ON change_log_operations (last_event_id, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_change_log_events_settled '
      'ON change_log_events (settled, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_change_log_events_operation '
      'ON change_log_events (operation_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_change_log_events_record '
      'ON change_log_events (table_name, record_id, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_change_log_events_root '
      'ON change_log_events (root_table, root_id)',
    );

    // Read first: this runs on every open from both isolates, and even a
    // no-op INSERT OR IGNORE takes the write lock.
    final context = await customSelect(
      'SELECT 1 FROM change_log_context WHERE id = 1',
    ).get();
    if (context.isEmpty) {
      await customStatement(
        'INSERT OR IGNORE INTO change_log_context (id) VALUES (1)',
      );
    }
  }
}
