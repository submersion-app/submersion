import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_smart_album.dart'
    as domain;

/// Smart albums: named saved library filters (Media section Phase 5).
///
/// Synced like any other user data -- the stored filter speaks in ids and
/// enum names that resolve the same way on every device.
class MediaSmartAlbumRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  Future<List<domain.MediaSmartAlbum>> getAll() async {
    final rows =
        await (_db.select(_db.mediaSmartAlbums)..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.name),
            ]))
            .get();
    return [for (final row in rows) _fromRow(row)];
  }

  Future<domain.MediaSmartAlbum> create({
    required String name,
    required MediaLibraryFilter filter,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db
        .into(_db.mediaSmartAlbums)
        .insert(
          MediaSmartAlbumsCompanion(
            id: Value(id),
            name: Value(name),
            filterJson: Value(jsonEncode(filter.toJson())),
            createdAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'mediaSmartAlbums',
      recordId: id,
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
    SyncEventBus.notifyLocalChange();
    return domain.MediaSmartAlbum(
      id: id,
      name: name,
      filter: filter,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> rename(String id, String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.mediaSmartAlbums,
    )..where((t) => t.id.equals(id))).write(
      MediaSmartAlbumsCompanion(name: Value(name), updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'mediaSmartAlbums',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> delete(String id) async {
    await (_db.delete(
      _db.mediaSmartAlbums,
    )..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(
      entityType: 'mediaSmartAlbums',
      recordId: id,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Emits whenever the album set changes, so the UI can re-read.
  Stream<void> watchChanges() {
    final count = countAll();
    return (_db.selectOnly(
      _db.mediaSmartAlbums,
    )..addColumns([count])).watchSingle().map((_) {});
  }

  domain.MediaSmartAlbum _fromRow(MediaSmartAlbum row) {
    // A filter this build cannot parse degrades to "everything" rather
    // than breaking the album list.
    MediaLibraryFilter filter = MediaLibraryFilter.none;
    try {
      final decoded = jsonDecode(row.filterJson);
      if (decoded is Map<String, dynamic>) {
        filter = MediaLibraryFilter.fromJson(decoded);
      }
    } on FormatException {
      filter = MediaLibraryFilter.none;
    }
    return domain.MediaSmartAlbum(
      id: row.id,
      name: row.name,
      filter: filter,
      sortOrder: row.sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
