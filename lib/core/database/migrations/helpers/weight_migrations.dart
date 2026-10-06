part of '../app_database_migrations.dart';

/// Weight presets.
extension WeightMigrations on AppDatabase {
  /// Reusable weighting rigs (issue #1609, v196). Idempotent `CREATE TABLE IF
  /// NOT EXISTS` for both the preset header and its entries, so a database that
  /// arrives by restore or sync-adopt (never runs onUpgrade) also gets them.
  Future<void> _assertWeightPresetTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS weight_presets (
        id TEXT NOT NULL PRIMARY KEY,
        diver_id TEXT REFERENCES divers(id),
        display_name TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS weight_preset_entries (
        id TEXT NOT NULL PRIMARY KEY,
        preset_id TEXT NOT NULL REFERENCES weight_presets(id) ON DELETE CASCADE,
        weight_type TEXT NOT NULL,
        amount_kg REAL NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_weight_preset_entries_preset '
      'ON weight_preset_entries(preset_id)',
    );
  }

  /// Idempotent DDL for the v270 weight name columns (issue #956) on
  /// dive_weights and weight_preset_entries. Called from the v270 rung and
  /// re-asserted in beforeOpen, so a database that arrives by restore or
  /// sync-adopt, or one a renumbered rung skipped, still gains them.
  Future<void> _assertWeightLabelColumns() async {
    for (final table in const ['dive_weights', 'weight_preset_entries']) {
      final cols = await customSelect("PRAGMA table_info('$table')").get();
      if (cols.isEmpty) continue;
      final names = cols.map((c) => c.read<String>('name')).toSet();
      if (names.contains('label')) continue;
      await customStatement(
        "ALTER TABLE $table ADD COLUMN label TEXT NOT NULL DEFAULT ''",
      );
    }
  }
}
