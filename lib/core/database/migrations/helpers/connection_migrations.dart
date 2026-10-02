part of '../app_database_migrations.dart';

/// Schema for the Connections explorer's saved maps (v235, issue #2322).
extension ConnectionMigrations on AppDatabase {
  /// v235: the saved-maps table and the sightings dive index. Idempotent,
  /// so the beforeOpen backstop can run it on every open. Each half is
  /// skipped on a partial fixture that lacks its parent table.
  Future<void> _assertConnectionMapsSchema() async {
    if (await _tableExists('divers')) {
      await Migrator(this).createTable(connectionMaps);
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_connection_maps_diver '
        'ON connection_maps(diver_id, sort_order)',
      );
    }
    if (await _tableExists('sightings')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sightings_dive_id '
        'ON sightings(dive_id)',
      );
    }
  }
}
