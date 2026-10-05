import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';

/// Writes a site attachment's user-editable details (issue #1039): its
/// category and size override. Never its name: the stored filename is how
/// other devices and the repair wizard find the file.
///
/// Narrow writers, like `MediaRepository.setManualElapsedSeconds`: each
/// writes only its own columns plus updatedAt and takes the row clock, so a
/// stale snapshot cannot roll back an upload stamp or a verification verdict
/// that landed in between. Kept out of MediaRepository, which is already far
/// past the file-size ceiling.
class SiteAttachmentRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(SiteAttachmentRepository);

  /// Applies [edit] to media row [id].
  ///
  /// Throws [StateError] when the row no longer exists (unlinked, or
  /// deleted by a sync, while the sheet was open), so the caller reports a
  /// failure instead of a sync record being queued for a missing row.
  Future<void> setAttachmentDetails(
    String id,
    AttachmentDetailsEdit edit,
  ) async {
    if (edit.isEmpty) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        final written =
            await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
              MediaCompanion(
                siteCategory: edit.category == null
                    ? const Value.absent()
                    : Value(edit.category!.value?.storageKey),
                displaySize: edit.displaySize == null
                    ? const Value.absent()
                    : Value(edit.displaySize!.value?.storageKey),
                updatedAt: Value(now),
              ),
            );
        if (written == 0) {
          throw StateError('Media $id no longer exists');
        }
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Set attachment details for media $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set attachment details for media: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Puts every row in [ids] into [category] (null uncategorizes), leaving
  /// each row's size override and name alone. One transaction, so a bulk
  /// assignment never lands half-done. Site selections are one site's
  /// attachments, far under SQLite's bound-variable ceiling.
  ///
  /// Returns how many rows were actually updated: ids unlinked since the
  /// selection was made are skipped and not counted.
  Future<int> setSiteCategory(
    List<String> ids,
    SiteAttachmentCategory? category,
  ) async {
    if (ids.isEmpty) return 0;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = await _db.transaction(() async {
        // Only rows that still exist get a sync record: an id unlinked by
        // another device since the selection was made is skipped.
        final existing =
            await (_db.selectOnly(_db.media)
                  ..addColumns([_db.media.id])
                  ..where(_db.media.id.isIn(ids)))
                .map((row) => row.read(_db.media.id)!)
                .get();
        if (existing.isEmpty) return 0;
        await (_db.update(_db.media)..where((t) => t.id.isIn(existing))).write(
          MediaCompanion(
            siteCategory: Value(category?.storageKey),
            updatedAt: Value(now),
          ),
        );
        for (final id in existing) {
          await _syncRepository.markRecordPending(
            entityType: 'media',
            recordId: id,
            localUpdatedAt: now,
          );
        }
        return existing.length;
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Set site category ${category?.storageKey} on $updated');
      return updated;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set site category on ${ids.length} media',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
