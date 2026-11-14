part of '../app_database_migrations.dart';

/// What an equipment set carries besides gear, and the body composition
/// inputs of the weight prediction (issue #4525).
extension SetBundleMigrations on AppDatabase {
  /// v363: the three junction tables under `equipment_sets`, each with a
  /// unique pair. Idempotent; called from the rung and the beforeOpen
  /// backstop. Skipped on a partial fixture missing any parent table.
  Future<void> _assertSetBundleTables() async {
    for (final parent in const [
      'equipment_sets',
      'weight_presets',
      'cylinder_configs',
    ]) {
      if (!await _tableExists(parent)) return;
    }
    final migrator = Migrator(this);
    await migrator.createTable(equipmentSetIncludes);
    await migrator.createTable(equipmentSetWeightPresets);
    await migrator.createTable(equipmentSetCylinderConfigs);
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_equipment_set_includes_pair '
      'ON equipment_set_includes(set_id, included_set_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS '
      'idx_equipment_set_weight_presets_pair '
      'ON equipment_set_weight_presets(set_id, preset_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS '
      'idx_equipment_set_cylinder_configs_pair '
      'ON equipment_set_cylinder_configs(set_id, config_id)',
    );
  }

  /// v363: divers.sex, divers.birth_year and
  /// diver_weight_entries.body_fat_percent. All nullable, and null means
  /// "not given", so no existing row is rewritten.
  Future<void> _assertBodyCompositionColumns() async {
    if (await _tableExists('divers')) {
      await _addColumnIfMissing('divers', 'sex', 'TEXT');
      await _addColumnIfMissing('divers', 'birth_year', 'INTEGER');
    }
    if (await _tableExists('diver_weight_entries')) {
      await _addColumnIfMissing(
        'diver_weight_entries',
        'body_fat_percent',
        'REAL',
      );
    }
  }
}
