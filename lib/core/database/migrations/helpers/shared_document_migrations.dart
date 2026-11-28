part of '../app_database_migrations.dart';

/// Documents shared through a shared site library (issue #4713, v395).
/// Idempotent, so it serves as the rung and the beforeOpen backstop.
extension SharedDocumentMigrations on AppDatabase {
  Future<void> _assertSharedDocumentSchema() async {
    // A library document belongs to no diver. The rebuild keeps every row,
    // index and trigger, and is a no-op once the column is nullable.
    await _dropNotNullByRebuild('documents', const {'diver_id': 'TEXT'});
    await _addMissingColumns('documents', {'shared_library_id': 'TEXT'});
    await _addMissingColumns('document_pages', {'library_file_id': 'TEXT'});
    if (!await _tableExists(sharedDocumentStates.actualTableName)) {
      await Migrator(this).createTable(sharedDocumentStates);
    }
  }
}
