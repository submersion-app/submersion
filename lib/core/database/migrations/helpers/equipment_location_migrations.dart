part of '../app_database_migrations.dart';

/// Equipment locations (v268).
extension EquipmentLocationMigrations on AppDatabase {
  /// Idempotent creation of `equipment_locations` and
  /// `equipment_location_moves`. Their indexes are in the canonical
  /// performance set, which beforeOpen asserts on every open. Skipped on a
  /// partial fixture without the parent tables, so its foreign keys never
  /// point nowhere. Safe from both the v268 rung and the beforeOpen
  /// backstop.
  Future<void> _assertEquipmentLocationSchema() async {
    for (final parent in const ['equipment', 'divers']) {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(parent)],
      ).get();
      if (rows.isEmpty) return;
    }
    await Migrator(this).createTable(equipmentLocations);
    await Migrator(this).createTable(equipmentLocationMoves);
  }
}
