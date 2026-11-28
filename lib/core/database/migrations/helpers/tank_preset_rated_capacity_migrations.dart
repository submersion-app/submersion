part of '../app_database_migrations.dart';

/// A custom tank preset's rated capacity (v390, issue #800).
extension TankPresetRatedCapacityMigrations on AppDatabase {
  /// `tank_presets.rated_capacity_cuft` (REAL, nullable): the manufacturer's
  /// rated capacity a copy of a built-in preset keeps, so an AL80 copy still
  /// reads 77.4 cuft. No backfill: an existing preset has none and shows the
  /// capacity worked out from its volume and pressure, as before. Safe from
  /// both the v390 rung and the beforeOpen backstop.
  Future<void> _assertTankPresetRatedCapacityColumn() async {
    await _addColumnIfMissing('tank_presets', 'rated_capacity_cuft', 'REAL');
  }
}
