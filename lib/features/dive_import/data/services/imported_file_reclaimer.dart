import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';

/// Refcounted reclamation of the stored import files (issue #478).
///
/// One import run points every dive it created at one content-addressed
/// `imported_files` row, so the row may only go once no surviving
/// `dive_data_sources` row names it. Every path that destroys such a row -- a
/// dive deletion, a diver deletion, a replaceSource re-download, a remote
/// tombstone -- calls [reclaimOrphans] afterwards rather than reasoning about
/// the refcount itself.
///
/// Reclamation stays local: a device never tells its peers to drop a stored
/// file. One that is a sync behind still has the dive, and would be told to
/// throw away bytes it needs. So each device decides from its own rows, which
/// is why the sync path sweeps from its own deletion handlers rather than
/// trusting a peer: `SyncDataSerializer.deleteRecord` calls [reclaimOrphans]
/// after applying a `dives` or `diveDataSources` tombstone, the two that can
/// remove the last reference, and routes an `importedFiles` tombstone through
/// [deleteIfUnreferenced] instead of deleting outright.
///
/// The refcount is the anti-join, not bookkeeping the callers carry: the
/// sweep asks which rows nothing names any more, which is the same answer
/// whatever deleted them, and is also the answer for a row orphaned by an
/// import that never got as far as writing its source row.
class ImportedFileReclaimer {
  ImportedFileReclaimer({AppDatabase Function()? database})
    : _database = database ?? _defaultDatabase;

  final AppDatabase Function() _database;

  /// Bound to the database the rows are deleted from, so the tombstones land
  /// beside them rather than in the global instance.
  SyncRepository get _sync => SyncRepository(database: _database());
  static const _log = LoggerService('ImportedFileReclaimer');

  static AppDatabase _defaultDatabase() => DatabaseService.instance.database;

  /// SQL for "no `dive_data_sources` row names this `imported_files` row".
  /// Indexed by `idx_dive_data_sources_imported_file`.
  static const _unreferenced =
      'NOT EXISTS (SELECT 1 FROM dive_data_sources '
      'WHERE imported_file_id = imported_files.id)';

  /// Deletes every stored file no source row references any more, and
  /// tombstones each so peers reclaim the same rows.
  ///
  /// Called after the rows are gone rather than before, so a failure here
  /// leaves an unreferenced file -- the failure mode that existed before this
  /// sweep did, and one the next call cleans up -- rather than a surviving row
  /// pointing at bytes that are not there.
  Future<void> reclaimOrphans() async {
    final db = _database();
    try {
      final orphans = await db
          .customSelect(
            'SELECT id FROM imported_files WHERE $_unreferenced',
            readsFrom: {db.importedFiles, db.diveDataSources},
          )
          .get();
      if (orphans.isEmpty) return;

      // Deleted by the same predicate rather than by the ids just read, so no
      // bound-variable limit applies however many rows are orphaned at once.
      await db.customStatement(
        'DELETE FROM imported_files WHERE $_unreferenced',
      );
      for (final row in orphans) {
        await _sync.logDeletion(
          entityType: ImportedFileRepository.entityType,
          recordId: row.read<String>('id'),
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      // Reclaiming disk is never worth failing the deletion that triggered it.
      _log.warning(
        'Could not reclaim orphaned imported files',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Deletes the stored file [id] only while nothing references it, for the
  /// remote-tombstone path.
  ///
  /// A peer that reclaimed the row has no way to know this device still holds
  /// a dive pointing at it -- its own changeset may not have arrived yet -- so
  /// applying its tombstone blindly would throw away bytes a live dive needs.
  /// Returns whether the row was removed.
  Future<bool> deleteIfUnreferenced(String id) async {
    final db = _database();
    await db.customStatement(
      'DELETE FROM imported_files WHERE id = ? AND $_unreferenced',
      [id],
    );
    return !await ImportedFileRepository(database: _database).exists(id);
  }
}
