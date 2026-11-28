part of '../app_database_migrations.dart';

/// When in the dive a species was seen (issue #5092). The column is
/// nullable and null means no time, so no existing sighting is rewritten.
extension SightingSeenAtMigrations on AppDatabase {
  /// v396: sightings.seen_at_seconds. Idempotent; called from the rung and
  /// the beforeOpen backstop.
  Future<void> _assertSightingSeenAtColumn() async {
    if (!await _tableExists('sightings')) return;
    await _addColumnIfMissing('sightings', 'seen_at_seconds', 'INTEGER');
  }
}
