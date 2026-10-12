part of '../app_database_migrations.dart';

/// Shared dive-site library schema (issue #2567, v289): five tables and the
/// `dive_sites.shared_library_id` column. Idempotent, so it serves as the
/// rung and the beforeOpen backstop.
extension SharedLibraryMigrations on AppDatabase {
  Future<void> _assertSharedLibrarySchema() async {
    final m = Migrator(this);
    final tables = <TableInfo>[
      sharedLibraries,
      sharedLibraryMembers,
      sharedLibraryMemberships,
      sharedSiteStates,
      sharedSiteSuggestions,
    ];
    for (final table in tables) {
      if (!await _tableExists(table.actualTableName)) {
        await m.createTable(table);
      }
    }
    final cols = await customSelect("PRAGMA table_info('dive_sites')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('shared_library_id')) {
      await customStatement(
        'ALTER TABLE dive_sites ADD COLUMN shared_library_id TEXT',
      );
    }
  }
}
