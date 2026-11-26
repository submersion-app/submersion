part of '../app_database_migrations.dart';

/// The side a weight is carried on (v383, issue #5028).
extension DiveWeightSideMigrations on AppDatabase {
  /// `dive_weights.side` (v383). Nullable, no backfill: null means both
  /// sides. Idempotent, so the ladder and the beforeOpen backstop can both
  /// call it.
  Future<void> _assertDiveWeightSideColumn() =>
      _addColumnIfMissing('dive_weights', 'side', 'TEXT');
}
