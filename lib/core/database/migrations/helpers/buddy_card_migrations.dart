part of '../app_database_migrations.dart';

/// Buddy card swap columns (issue #3728, v324).
extension BuddyCardMigrations on AppDatabase {
  static const _columns = {
    'buddies': {
      'card_id': 'TEXT',
      'social_handle': 'TEXT',
      'card_dive_count': 'INTEGER',
      'card_diving_since': 'INTEGER',
      'card_last_dive': 'INTEGER',
      'card_received_at': 'INTEGER',
    },
    'certifications': {'card_id': 'TEXT'},
    'divers': {'social_handle': 'TEXT', 'buddy_card_share': 'TEXT'},
  };

  /// Adds whichever of the v324 columns a table lacks. Idempotent, so the
  /// ladder and the beforeOpen backstop (a database that arrived by restore
  /// or sync-adopt) can both call it; a table not created yet is skipped.
  Future<void> _assertBuddyCardColumns() async {
    for (final table in _columns.entries) {
      final cols = await customSelect(
        "PRAGMA table_info('${table.key}')",
      ).get();
      if (cols.isEmpty) continue;
      final names = cols.map((c) => c.read<String>('name')).toSet();
      for (final column in table.value.entries) {
        if (names.contains(column.key)) continue;
        await customStatement(
          'ALTER TABLE ${table.key} ADD COLUMN ${column.key} ${column.value}',
        );
      }
    }
  }
}
