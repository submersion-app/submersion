part of '../app_database_migrations.dart';

/// Equipment, equipment sets, attributes, tags and sharing.
extension EquipmentMigrations on AppDatabase {
  /// v203: equipment_components (issue #1487), the assembly template. Pure
  /// CREATE IF NOT EXISTS so it is safe from both onUpgrade and the beforeOpen
  /// backstop.
  Future<void> _assertEquipmentComponentsTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS equipment_components (
        id TEXT NOT NULL PRIMARY KEY,
        parent_equipment_id TEXT NOT NULL
          REFERENCES equipment(id) ON DELETE CASCADE,
        component_equipment_id TEXT NOT NULL
          REFERENCES equipment(id) ON DELETE CASCADE,
        role TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT,
        UNIQUE (parent_equipment_id, component_equipment_id)
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_equipment_components_parent '
      'ON equipment_components(parent_equipment_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_equipment_components_component '
      'ON equipment_components(component_equipment_id)',
    );
  }

  /// v203: the two nullable provenance columns on each gear junction
  /// (issue #1487). PRAGMA-guarded per table and per column so a healthy
  /// database no-ops and a partial fixture does not throw. Nothing writes
  /// them until the dive side lands; adding them here keeps the ladder to
  /// one rung for the feature.
  ///
  /// Each column is added only once the table it references exists. SQLite
  /// accepts a REFERENCES clause naming a table that is not there, but with
  /// foreign keys on it checks that clause at the next DML on the junction
  /// and fails with "no such table". Older rungs' minimal-fixture tests hold
  /// a junction without its parents, and the beforeOpen backstop re-runs
  /// this on every open, so a real database always gets both columns.
  Future<void> _assertGearProvenanceColumns() async {
    final tables = (await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get()).map((r) => r.read<String>('name')).toSet();
    final hasEquipment = tables.contains('equipment');
    final hasSets = tables.contains('equipment_sets');
    for (final table in ['dive_equipment', 'dive_plan_equipment']) {
      final cols = await customSelect("PRAGMA table_info('$table')").get();
      if (cols.isEmpty) continue;
      final names = cols.map((c) => c.read<String>('name')).toSet();
      if (hasEquipment && !names.contains('via_equipment_id')) {
        await customStatement(
          'ALTER TABLE $table ADD COLUMN via_equipment_id TEXT '
          'REFERENCES equipment (id) ON DELETE SET NULL',
        );
      }
      if (hasSets && !names.contains('via_set_id')) {
        await customStatement(
          'ALTER TABLE $table ADD COLUMN via_set_id TEXT '
          'REFERENCES equipment_sets (id) ON DELETE SET NULL',
        );
      }
    }
  }

  /// v124: equipment_attributes table + indexes. Idempotent so it is safe to
  /// call from both onUpgrade and the beforeOpen backstop. Deliberately does
  /// NOT copy legacy data -- see _migrateLegacyEquipmentColumnsToAttributes,
  /// which must run exactly once (re-running it on open would resurrect
  /// attribute rows the user has since cleared).
  Future<void> _assertEquipmentAttributesSchema() async {
    await Migrator(this).createTable(equipmentAttributes);
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_equipment_attributes_equipment_id
      ON equipment_attributes(equipment_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_equipment_attributes_key_num
      ON equipment_attributes(attr_key, value_num)
    ''');
  }

  /// v124 data copy: legacy equipment.size/thickness/buoyancy_kg/weight_kg
  /// into equipment_attributes rows. Deterministic ids and parent-row
  /// timestamps make the result byte-identical on every device that runs the
  /// migration, so no sync traffic is needed to converge; hlc stays NULL
  /// (LWW falls back to updated_at, same as pre-HLC equipment rows).
  /// INSERT OR IGNORE keeps a re-run harmless, but this is still only called
  /// from onUpgrade (never beforeOpen) to avoid resurrecting cleared values.
  Future<void> _migrateLegacyEquipmentColumnsToAttributes() async {
    // PRAGMA-guarded like every other migration helper: a database without
    // the equipment table or without a given legacy column (minimal
    // old-schema test fixtures; ancient databases) simply has nothing to
    // copy for that column.
    final cols = await customSelect("PRAGMA table_info('equipment')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.isEmpty) return;
    // Every copy reads the parent-row timestamps.
    if (!names.contains('created_at') || !names.contains('updated_at')) {
      return;
    }
    if (names.contains('size')) await _copyLegacySizeColumn();
    if (names.contains('thickness')) await _copyLegacyThicknessColumn();
    if (names.contains('buoyancy_kg')) await _copyLegacyBuoyancyColumn();
    if (names.contains('weight_kg')) await _copyLegacyDryWeightColumn();
  }

  Future<void> _copyLegacySizeColumn() async {
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_size', id, 'size', 0, TRIM(size), NULL,
             0, created_at, updated_at, NULL
      FROM equipment WHERE size IS NOT NULL AND TRIM(size) != ''
    ''');
  }

  Future<void> _copyLegacyThicknessColumn() async {
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_thickness_mm', id, 'thickness_mm', 0,
             TRIM(thickness),
             CASE WHEN TRIM(thickness) GLOB '[0-9]*'
                  THEN CAST(TRIM(thickness) AS REAL) ELSE NULL END,
             0, created_at, updated_at, NULL
      FROM equipment WHERE thickness IS NOT NULL AND TRIM(thickness) != ''
    ''');
  }

  Future<void> _copyLegacyBuoyancyColumn() async {
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_buoyancy_kg', id, 'buoyancy_kg', 0, NULL,
             buoyancy_kg, 0, created_at, updated_at, NULL
      FROM equipment WHERE buoyancy_kg IS NOT NULL
    ''');
  }

  Future<void> _copyLegacyDryWeightColumn() async {
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_dry_weight_kg', id, 'dry_weight_kg', 0, NULL,
             weight_kg, 0, created_at, updated_at, NULL
      FROM equipment WHERE weight_kg IS NOT NULL
    ''');
  }

  /// v112: equipment.thickness column. Idempotent so it is safe to call from
  /// both onUpgrade and the beforeOpen backstop.
  Future<void> _assertEquipmentThicknessColumn() async {
    final cols = await customSelect("PRAGMA table_info('equipment')").get();
    final hasThickness = cols.any((c) => c.read<String>('name') == 'thickness');
    if (cols.isNotEmpty && !hasThickness) {
      await customStatement('ALTER TABLE equipment ADD COLUMN thickness TEXT');
    }
  }

  /// v220: equipment_sets.auto_apply_on_computer_import (issue #1020).
  /// Additive column, default off, so pre-existing sets keep today's
  /// behavior until a diver opts in. Idempotent, so it is safe to call from
  /// both onUpgrade and the beforeOpen backstop.
  Future<void> _assertEquipmentSetComputerAutoApplyColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('equipment_sets')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('auto_apply_on_computer_import')) {
      await customStatement(
        'ALTER TABLE equipment_sets '
        'ADD COLUMN auto_apply_on_computer_import INTEGER NOT NULL '
        'DEFAULT 0',
      );
    }
  }

  /// v229: equipment_sets.show_figure (issue #2326). Additive, not null,
  /// default 0, so every existing set comes up with the figure off.
  /// Idempotent, so it is safe to call from both onUpgrade and the
  /// beforeOpen backstop.
  Future<void> _assertEquipmentSetShowFigureColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('equipment_sets')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('show_figure')) {
      await customStatement(
        'ALTER TABLE equipment_sets '
        'ADD COLUMN show_figure INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  /// v111: equipment_sets.is_default column + equipment_set_geofences table.
  /// Idempotent (createTable is IF NOT EXISTS; the ALTER is PRAGMA-guarded) so
  /// it is safe to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertEquipmentSetDefaultAndGeofenceSchema() async {
    await Migrator(this).createTable(equipmentSetGeofences);
    final cols = await customSelect(
      "PRAGMA table_info('equipment_sets')",
    ).get();
    final hasIsDefault = cols.any(
      (c) => c.read<String>('name') == 'is_default',
    );
    if (cols.isNotEmpty && !hasIsDefault) {
      await customStatement(
        'ALTER TABLE equipment_sets ADD COLUMN is_default '
        'INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1))',
      );
    }
  }

  /// Idempotent creation of the v219 equipment tag schema (issue #1942): the
  /// `equipment_tags` junction and its (equipment, tag) unique index. Called
  /// from the v219 rung and the beforeOpen backstop.
  ///
  /// Skipped on a partial migration-test fixture that lacks either parent
  /// table, so a fixture written for an older rung does not gain a junction
  /// whose foreign keys point nowhere.
  Future<void> _assertEquipmentTagSchema() async {
    for (final parent in const ['equipment', 'tags']) {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(parent)],
      ).get();
      if (rows.isEmpty) return;
    }
    await Migrator(this).createTable(equipmentTags);
    await assertEquipmentTagUniqueness(this);
  }

  /// Idempotent creation of the v234 equipment sharing schema (issue #2046):
  /// `equipment_shares` with its (equipment, diver) unique index, and
  /// `equipment_ownership_events`. Called from the v234 rung and the
  /// beforeOpen backstop.
  ///
  /// Skipped on a partial migration-test fixture that lacks either parent
  /// table, so a fixture written for an older rung does not gain tables
  /// whose foreign keys point nowhere.
  Future<void> _assertEquipmentSharingSchema() async {
    for (final parent in const ['equipment', 'divers']) {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(parent)],
      ).get();
      if (rows.isEmpty) return;
    }
    await Migrator(this).createTable(equipmentShares);
    await Migrator(this).createTable(equipmentOwnershipEvents);
    await assertEquipmentShareUniqueness(this);
  }
}
