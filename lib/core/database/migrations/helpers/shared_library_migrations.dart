part of '../app_database_migrations.dart';

/// Shared dive-site library schema (issue #2567, v289): seven tables, the
/// `dive_sites.shared_library_id` column, and the key, trust and backup
/// columns added before v289 shipped. Idempotent, so it serves as the rung
/// and the beforeOpen backstop, which is how a database already past 289
/// picks up the later columns.
extension SharedLibraryMigrations on AppDatabase {
  Future<void> _assertSharedLibrarySchema() async {
    final m = Migrator(this);
    final tables = <TableInfo>[
      sharedLibraries,
      sharedLibraryMembers,
      sharedLibraryMemberships,
      sharedSiteStates,
      sharedSiteSuggestions,
      sharedLibraryBackups,
      librarySiteNotes,
    ];
    for (final table in tables) {
      if (!await _tableExists(table.actualTableName)) {
        await m.createTable(table);
      }
    }
    await _addMissingColumns('dive_sites', {'shared_library_id': 'TEXT'});
    await _addMissingColumns('shared_library_memberships', {
      'signing_public_key': 'TEXT',
      'signing_private_key': 'TEXT',
      'library_key_id': 'TEXT',
      'library_key': 'TEXT',
    });
    await _addMissingColumns('shared_library_members', {
      'public_key': 'TEXT',
      'card_verified':
          'INTEGER NOT NULL DEFAULT 0 CHECK ("card_verified" IN (0, 1))',
    });
    await _addMissingColumns('shared_libraries', {
      'roles_rejected':
          'INTEGER NOT NULL DEFAULT 0 CHECK ("roles_rejected" IN (0, 1))',
      'pending_roles_json': 'TEXT',
      'encrypted': 'INTEGER NOT NULL DEFAULT 0 CHECK ("encrypted" IN (0, 1))',
      'key_id': 'TEXT',
      'last_auto_backup_at': 'INTEGER',
      'notes_backfilled':
          'INTEGER NOT NULL DEFAULT 0 CHECK ("notes_backfilled" IN (0, 1))',
      'spare_key_id': 'TEXT',
      'spare_key': 'TEXT',
    });
  }

  Future<void> _addMissingColumns(
    String table,
    Map<String, String> columns,
  ) async {
    final rows = await customSelect("PRAGMA table_info('$table')").get();
    if (rows.isEmpty) return;
    final have = rows.map((c) => c.read<String>('name')).toSet();
    for (final e in columns.entries) {
      if (!have.contains(e.key)) {
        await customStatement(
          'ALTER TABLE $table ADD COLUMN ${e.key} ${e.value}',
        );
      }
    }
  }
}
