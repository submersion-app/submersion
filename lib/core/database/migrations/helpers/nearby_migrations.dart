part of '../app_database_migrations.dart';

/// Nearby Bluetooth sync (issue #3731).
extension NearbyMigrations on AppDatabase {
  /// v320: the device-local paired-devices table and the publish state's
  /// relay floor. Idempotent.
  Future<void> _assertNearbySchema() async {
    if (!await _tableExists('nearby_peers')) {
      await Migrator(this).createTable(nearbyPeers);
    }
    if (await _tableExists('local_publish_states')) {
      await _addColumnIfMissing(
        'local_publish_states',
        'relay_floor_hlc',
        'TEXT',
      );
    }
  }
}
