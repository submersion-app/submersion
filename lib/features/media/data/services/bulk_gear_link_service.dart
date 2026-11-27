import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/existing_row_ids.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/data/repositories/media_gear_repository.dart';

/// Links gear to and unlinks it from many photos at once, with undo (issue
/// #5046), as BulkTagService does for their tags.
///
/// Only junction rows change: no photo or gear row is written or marked
/// pending, so an edit made to a photo between Apply and Undo survives both.
class BulkGearLinkService {
  BulkGearLinkService(this._repository);

  final MediaGearRepository _repository;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Links [addGearIds] to every photo in [mediaIds] and unlinks
  /// [removeGearIds] from every one, in one transaction, then notifies once.
  ///
  /// Returns each photo's gear ids as they were before, empty for a photo
  /// that had none, for [undo]. An empty change writes nothing and returns
  /// an empty map.
  Future<Map<String, List<String>>> apply({
    required List<String> mediaIds,
    required Set<String> addGearIds,
    required Set<String> removeGearIds,
  }) => ChangeLogScope.bulk(
    DatabaseService.instance.databaseOrNull,
    label: ChangeLogLabels.bulkEdit,
    body: () async {
      if (mediaIds.isEmpty || (addGearIds.isEmpty && removeGearIds.isEmpty)) {
        return const <String, List<String>>{};
      }
      final prior = await _db.transaction(() async {
        final before = await _repository.gearIdsByMedia(mediaIds);
        await _repository.addGear(mediaIds, addGearIds.toList(), notify: false);
        await _repository.removeGear(
          mediaIds,
          removeGearIds.toList(),
          notify: false,
        );
        return <String, List<String>>{
          for (final id in mediaIds)
            id: List<String>.unmodifiable(before[id] ?? const <String>{}),
        };
      });
      SyncEventBus.notifyLocalChange();
      return prior;
    },
  );

  /// Puts every photo in [prior] back to exactly its snapshot, skipping a
  /// photo deleted since and leaving out gear deleted since, so Undo never
  /// names a row that is gone.
  Future<void> undo(Map<String, List<String>> prior) => ChangeLogScope.bulk(
    DatabaseService.instance.databaseOrNull,
    label: ChangeLogLabels.bulkEdit,
    body: () async {
      if (prior.isEmpty) return;
      await _db.transaction(() async {
        final liveMedia = await existingRowIds(_db, _db.media, prior.keys);
        final liveGear = await existingRowIds(_db, _db.equipment, {
          for (final ids in prior.values) ...ids,
        });
        for (final entry in prior.entries) {
          if (!liveMedia.contains(entry.key)) continue;
          await _repository.replaceGear(entry.key, [
            for (final id in entry.value)
              if (liveGear.contains(id)) id,
          ], notify: false);
        }
      });
      SyncEventBus.notifyLocalChange();
    },
  );
}
