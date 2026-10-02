part of '../app_database_migrations.dart';

/// Schema probes shared by every other migration file.
extension SupportMigrations on AppDatabase {
  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String ddl,
  ) async {
    final cols = await customSelect("PRAGMA table_info('$table')").get();
    if (cols.isEmpty) return; // partial fixture database: table absent
    if (cols.any((c) => c.read<String>('name') == column)) return;
    await customStatement('ALTER TABLE $table ADD COLUMN $column $ddl');
  }

  /// True when [table] exists in this database right now.
  Future<bool> _tableExists(String table) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(table)],
    ).get();
    return rows.isNotEmpty;
  }

  /// The `user_version` this database carries on disk right now.
  Future<int> _storedSchemaVersion() async {
    final row = await customSelect('PRAGMA user_version').getSingle();
    return (row.data.values.first as int?) ?? 0;
  }
}
