part of '../app_database_migrations.dart';

/// How many animals a sighting records: Seen, a REEF group, or an exact
/// count (issue #4337). The column is nullable and null means exact, so no
/// existing sighting is rewritten.
extension SightingAbundanceMigrations on AppDatabase {
  /// v350: sightings.abundance. Idempotent; called from the rung and the
  /// beforeOpen backstop.
  Future<void> _assertSightingAbundanceColumn() async {
    if (!await _tableExists('sightings')) return;
    await _addColumnIfMissing('sightings', 'abundance', 'TEXT');
  }
}
