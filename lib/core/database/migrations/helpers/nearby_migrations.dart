part of '../app_database_migrations.dart';

/// Nearby Bluetooth sync (issue #3731).
extension NearbyMigrations on AppDatabase {
  /// v320: the device-local paired-devices table. Idempotent.
  Future<void> _assertNearbyPeersTable() async {
    if (await _tableExists('nearby_peers')) return;
    await Migrator(this).createTable(nearbyPeers);
  }
}
