part of '../app_database_migrations.dart';

/// The equipment condition engine.
extension EquipmentConditionMigrations on AppDatabase {
  /// v202: equipment condition intelligence, phase 1. Idempotent; called
  /// from the v202 onUpgrade block and the beforeOpen backstop.
  Future<void> _assertEquipmentConditionSchema() async {
    // The three links reference equipment. A real database always has that
    // table; a partial-schema migration fixture may not, and with foreign
    // keys on, SQLite refuses every later insert into a table whose FK
    // parent is missing ("no such table: main.equipment"). Those fixtures
    // get a plain column instead.
    final equipmentExists = await _tableExists('equipment');
    final equipmentRef = equipmentExists
        ? 'TEXT REFERENCES equipment(id) ON DELETE SET NULL'
        : 'TEXT';
    await _addColumnIfMissing('equipment', 'parent_equipment_id', equipmentRef);
    await _addColumnIfMissing(
      'dive_tanks',
      'regulator_equipment_id',
      equipmentRef,
    );
    await _addColumnIfMissing('incidents', 'equipment_id', equipmentRef);
    await _addColumnIfMissing('trips', 'expected_dives', 'INTEGER');
    await _addColumnIfMissing('trips', 'expected_runtime_minutes', 'INTEGER');
    await _assertExposureIntervalColumns();
    await _addColumnIfMissing(
      'diver_settings',
      'cold_water_threshold_c',
      'REAL NOT NULL DEFAULT 10.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'deep_dive_threshold_m',
      'REAL NOT NULL DEFAULT 30.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'high_o2_threshold_percent',
      'REAL NOT NULL DEFAULT 40.0',
    );
    // The four tables reference dives, divers and equipment. Same fixture
    // rule as above: a child table whose FK parent is absent makes SQLite
    // refuse cascades into it, so each is created only when its parents
    // exist. Real databases always have all three.
    final divesExist = await _tableExists('dives');
    final diversExist = await _tableExists('divers');
    final m = Migrator(this);
    if (divesExist) await m.createTable(diveSensorSummaries);
    if (divesExist && diversExist && equipmentExists) {
      await m.createTable(equipmentObservations);
    }
    if (equipmentExists) {
      await m.createTable(equipmentFindings);
      await m.createTable(equipmentConditionReviews);
    }
    // Indexes on pre-existing tables are guarded on the table being present:
    // partial-schema migration fixtures open without equipment or dive_tanks
    // and would otherwise fail on "no such table".
    if (await _tableExists('equipment')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_equipment_parent '
        'ON equipment(parent_equipment_id)',
      );
    }
    if (await _tableExists('dive_tanks')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_dive_tanks_regulator '
        'ON dive_tanks(regulator_equipment_id)',
      );
    }
    if (await _tableExists('equipment_observations')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_equipment_observations_equipment '
        'ON equipment_observations(equipment_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_equipment_observations_dive '
        'ON equipment_observations(dive_id)',
      );
    }
    if (await _tableExists('equipment_findings')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_equipment_findings_equipment '
        'ON equipment_findings(equipment_id)',
      );
    }
  }
}
