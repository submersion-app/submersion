part of '../app_database_migrations.dart';

/// What the on-device model found on each photo (issue #4668).
extension IdentificationMigrations on AppDatabase {
  /// v375: the two marine life identification tables and their media index.
  /// Idempotent. Neither table references media, so nothing is needed first.
  Future<void> _assertMediaIdentificationTables() async {
    final migrator = Migrator(this);
    await migrator.createTable(mediaIdentificationRuns);
    await migrator.createTable(mediaIdentifications);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_identifications_media '
      'ON media_identifications(media_id)',
    );
  }
}
