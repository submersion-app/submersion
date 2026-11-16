part of '../app_database_migrations.dart';

/// The dive types a diver starred to list first in the pickers (v371, issue
/// #4413).
extension DiveTypeFavouritesMigrations on AppDatabase {
  /// `diver_settings.favourite_dive_type_ids` (v371, issue #4413). Nullable,
  /// no backfill. Safe from both the v371 rung and the beforeOpen backstop.
  Future<void> _assertFavouriteDiveTypeIdsColumn() =>
      _addColumnIfMissing('diver_settings', 'favourite_dive_type_ids', 'TEXT');
}
