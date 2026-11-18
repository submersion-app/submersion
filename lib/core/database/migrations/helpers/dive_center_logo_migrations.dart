part of '../app_database_migrations.dart';

/// A dive center's logo (v373, issue #4460).
extension DiveCenterLogoMigrations on AppDatabase {
  /// `dive_centers.logo` (v373). Nullable, no backfill: a center with no logo
  /// draws the store icon, as every center did before. Safe from both the
  /// v373 rung and the beforeOpen backstop.
  Future<void> _assertDiveCenterLogoColumn() =>
      _addColumnIfMissing('dive_centers', 'logo', 'BLOB');
}
