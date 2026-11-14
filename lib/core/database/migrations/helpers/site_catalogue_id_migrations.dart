part of '../app_database_migrations.dart';

/// The built-in catalogue record a site was adopted from (v363).
extension SiteCatalogueIdMigrations on AppDatabase {
  /// `dive_sites.catalogue_id`. Nullable, so an older peer omits it and a
  /// site made before this column simply has no link. Safe from both the
  /// v363 rung and the beforeOpen backstop.
  Future<void> _assertSiteCatalogueIdColumn() =>
      _addColumnIfMissing('dive_sites', 'catalogue_id', 'TEXT');
}
