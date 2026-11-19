part of '../app_database_migrations.dart';

/// The marks on a species tag the app applied (issue #4727).
extension AppTagMigrations on AppDatabase {
  /// v378: whether the diver has yet to confirm a tag the app applied, and
  /// whether that tag created its sighting or species. Columns only, nothing
  /// to backfill: null in all three is the diver's own tag. Idempotent.
  Future<void> _assertMediaSpeciesAppTagColumns() async {
    for (final column in [
      'unconfirmed',
      'created_sighting',
      'created_species',
    ]) {
      await _addColumnIfMissing('media_species', column, 'INTEGER');
    }
  }
}
