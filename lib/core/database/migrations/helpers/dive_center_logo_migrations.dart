part of '../app_database_migrations.dart';

/// A dive center's logo (v372, issue #4460).
extension DiveCenterLogoMigrations on AppDatabase {
  /// `dive_centers.logo` (v372). Nullable, no backfill: a center with no logo
  /// draws the store icon, as every center did before. Safe from both the
  /// v372 rung and the beforeOpen backstop.
  Future<void> _assertDiveCenterLogoColumn() =>
      _addColumnIfMissing('dive_centers', 'logo', 'BLOB');
}
