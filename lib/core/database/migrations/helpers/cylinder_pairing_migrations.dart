part of '../app_database_migrations.dart';

/// Twin set pairings of two cylinders (issue #4242).
extension CylinderPairingMigrations on AppDatabase {
  /// Idempotent creation of the v343 `cylinder_pairings` table, its two
  /// lookup indexes, and the two nullable columns that tie a twin fill's rows
  /// (`cylinder_fills.filled_together_id`) and name a twin set tank's second
  /// cylinder (`dive_tanks.twin_passport_id`). No backfill. The table is
  /// skipped on a partial migration-test fixture without `equipment`, and a
  /// column on one without its table. Safe from both the v343 rung and the
  /// beforeOpen backstop. The indexes are in the canonical performance set
  /// too; they are made here so the rung leaves a complete schema.
  Future<void> _assertTwinSetSchema() async {
    if (await _tableExists('equipment')) {
      await Migrator(this).createTable(cylinderPairings);
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_cylinder_pairings_a '
        'ON cylinder_pairings(cylinder_a_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_cylinder_pairings_b '
        'ON cylinder_pairings(cylinder_b_id)',
      );
    }
    await _addColumnIfMissing('cylinder_fills', 'filled_together_id', 'TEXT');
    if (await _tableExists('cylinder_fills')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_cylinder_fills_together '
        'ON cylinder_fills(filled_together_id)',
      );
    }
    await _addColumnIfMissing('dive_tanks', 'twin_passport_id', 'TEXT');
    if (await _tableExists('dive_tanks')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_dive_tanks_twin_passport_id '
        'ON dive_tanks(twin_passport_id)',
      );
    }
  }

  /// Test hook: re-assert the v343 schema on demand so tests can prove the
  /// backstop is idempotent.
  Future<void> assertTwinSetSchemaForTest() => _assertTwinSetSchema();
}
