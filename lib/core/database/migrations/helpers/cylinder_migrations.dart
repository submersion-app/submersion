part of '../app_database_migrations.dart';

/// Cylinder configurations, transmitters and fills.
extension CylinderMigrations on AppDatabase {
  /// Transmitter registry (issue #1365, v200). Idempotent so a database that
  /// arrives by restore or sync-adopt (never runs onUpgrade) also gets it.
  Future<void> _assertTransmitterTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS transmitters (
        id TEXT NOT NULL PRIMARY KEY,
        diver_id TEXT REFERENCES divers(id),
        transmitter_serial TEXT,
        dive_computer_id TEXT REFERENCES dive_computers(id) ON DELETE SET NULL,
        channel_index INTEGER,
        label TEXT NOT NULL,
        tank_role TEXT NOT NULL,
        volume_l REAL,
        working_pressure_bar REAL,
        tank_material TEXT,
        preset_name TEXT,
        equipment_id TEXT REFERENCES equipment(id) ON DELETE SET NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transmitters_serial '
      'ON transmitters(transmitter_serial)',
    );
  }

  /// v139: cylinder configuration tables. CREATE TABLE IF NOT EXISTS, so this
  /// is safe to call from both onUpgrade and the beforeOpen backstop
  /// (parallel-branch version-collision self-heal).
  ///
  /// o2_percent / he_percent carry the same non-null defaults as dive_tanks
  /// so a configuration cylinder is never in an "unset gas" state.
  Future<void> _assertCylinderConfigSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cylinder_configs (
        id TEXT NOT NULL PRIMARY KEY,
        diver_id TEXT REFERENCES divers (id),
        equipment_id TEXT REFERENCES equipment (id) ON DELETE SET NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cylinder_config_items (
        id TEXT NOT NULL PRIMARY KEY,
        config_id TEXT NOT NULL
          REFERENCES cylinder_configs (id) ON DELETE CASCADE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        label TEXT,
        tank_role TEXT NOT NULL,
        volume_l REAL,
        working_pressure_bar REAL,
        tank_material TEXT,
        o2_percent REAL NOT NULL DEFAULT 21.0,
        he_percent REAL NOT NULL DEFAULT 0.0,
        default_start_pressure_bar REAL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cylinder_configs_equipment '
      'ON cylinder_configs (equipment_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cylinder_config_items_config '
      'ON cylinder_config_items (config_id)',
    );
  }

  /// Test hook: re-assert the v139 tables on demand so tests can prove the
  /// stranded-database self-heal path is idempotent.
  Future<void> assertCylinderConfigSchemaForTest() =>
      _assertCylinderConfigSchema();

  /// Idempotent creation of the v228 `cylinder_fills` table and its two
  /// lookup indexes (issue #2334). Called from the v228 rung and the
  /// beforeOpen backstop. Skipped on a partial migration-test fixture that
  /// lacks either parent table.
  Future<void> _assertCylinderFillsSchema() async {
    for (final parent in const ['divers', 'equipment']) {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(parent)],
      ).get();
      if (rows.isEmpty) return;
    }
    await Migrator(this).createTable(cylinderFills);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cylinder_fills_passport '
      'ON cylinder_fills(passport_id, filled_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cylinder_fills_equipment '
      'ON cylinder_fills(equipment_id)',
    );
  }
}
