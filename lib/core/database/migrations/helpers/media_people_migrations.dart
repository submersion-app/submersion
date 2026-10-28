part of '../app_database_migrations.dart';

/// People tagged on photos and videos (issue #1745).
extension MediaPeopleMigrations on AppDatabase {
  /// v326: the media_people table and its lookup indexes. Idempotent.
  Future<void> _assertMediaPeopleSchema() async {
    if (!await _tableExists('media_people')) {
      await Migrator(this).createTable(mediaPeople);
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_people_media '
      'ON media_people (media_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_people_buddy '
      'ON media_people (buddy_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_people_diver '
      'ON media_people (diver_id)',
    );
  }
}
