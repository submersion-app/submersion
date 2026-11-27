part of '../app_database_migrations.dart';

/// The side a weight is carried on (v386, issue #5028).
extension DiveWeightSideMigrations on AppDatabase {
  /// `dive_weights.side` and `weight_preset_entries.side` (v386). Nullable,
  /// no backfill: null means both sides. A preset keeps its entries' sides,
  /// so a preset or a set applied to a dive brings them back. Idempotent, so
  /// the ladder and the beforeOpen backstop can both call it.
  Future<void> _assertWeightSideColumns() async {
    await _addColumnIfMissing('dive_weights', 'side', 'TEXT');
    await _addColumnIfMissing('weight_preset_entries', 'side', 'TEXT');
  }
}
