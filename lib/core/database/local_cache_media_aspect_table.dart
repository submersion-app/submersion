import 'package:drift/drift.dart';

/// The displayed shape of each media library thumbnail, learned from its
/// decoded image (issue #4738).
///
/// The stored `width` / `height` of a media item are the container's, with no
/// EXIF rotation applied, so a portrait camera shot reads as landscape. The
/// decoded thumbnail is upright, and its ratio is kept here so the library
/// lays the item out right from then on.
///
/// Local-only by construction: every device learns it again from thumbnails
/// it draws anyway, so it carries no HLC, is never synced and is never backed
/// up.
class MediaAspectCache extends Table {
  @override
  String get tableName => 'media_aspect_cache';

  TextColumn get mediaId => text()();

  /// Width over height, as the thumbnail decoded.
  RealColumn get ratio => real()();

  /// The item's stored size when the ratio was learned. A different stored
  /// size later (the item was relinked or re-read) makes the row stale.
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();

  IntColumn get learnedAt => integer()();

  @override
  Set<Column> get primaryKey => {mediaId};
}

/// The table as [MediaAspectCache] declares it, for the open backstop that
/// heals a database a colliding branch stamped at v26 first. Keep the columns
/// in step with the class.
const String kCreateMediaAspectCacheSql = '''
  CREATE TABLE IF NOT EXISTS media_aspect_cache (
    media_id TEXT NOT NULL,
    ratio REAL NOT NULL,
    width INTEGER NULL,
    height INTEGER NULL,
    learned_at INTEGER NOT NULL,
    PRIMARY KEY (media_id)
  )
''';
