part of '../app_database_migrations.dart';

/// What a diver has settled about built-in catalogue records (v369).
extension SiteCatalogueAnswersMigrations on AppDatabase {
  /// `dive_sites.catalogue_answers`, and the link and answers a profile
  /// keeps for a shared library site in `library_site_notes`. All nullable,
  /// so an older peer omits them and a row from before simply has none.
  /// Safe from both the v369 rung and the beforeOpen backstop.
  Future<void> _assertSiteCatalogueAnswersColumns() async {
    await _addColumnIfMissing('dive_sites', 'catalogue_answers', 'TEXT');
    await _addColumnIfMissing('library_site_notes', 'catalogue_id', 'TEXT');
    await _addColumnIfMissing(
      'library_site_notes',
      'catalogue_answers',
      'TEXT',
    );
  }
}
