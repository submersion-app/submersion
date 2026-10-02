part of '../app_database_migrations.dart';

/// Saved queries of the entity query language.
extension QueryMigrations on AppDatabase {
  /// Idempotent creation of the v238 `saved_queries` table and its lookup
  /// index (issue #2365). Called from the v238 rung and the beforeOpen
  /// backstop. Skipped on a partial migration-test fixture that lacks the
  /// divers table its foreign key points at.
  Future<void> _assertSavedQueriesSchema() async {
    if (!await _tableExists('divers')) return;
    await Migrator(this).createTable(savedQueries);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_saved_queries_diver '
      'ON saved_queries(diver_id, subject, sort_order)',
    );
  }
}
