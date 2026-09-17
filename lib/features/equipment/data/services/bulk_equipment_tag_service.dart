import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';

/// Puts tags on and takes them off many equipment items at once, with undo
/// (issue #1942).
///
/// Only `equipment_tags` rows change. No equipment row is written or marked
/// pending, so an edit made to an item between Apply and Undo survives both,
/// and a stale whole-item snapshot can never beat a peer's newer edit
/// (#1769).
class BulkEquipmentTagService {
  BulkEquipmentTagService(this._repository);

  final EquipmentTagRepository _repository;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Puts [addTagIds] on every item in [equipmentIds] and takes
  /// [removeTagIds] off every one, in one transaction, then notifies once.
  ///
  /// Returns each item's tag ids as they were before, with an empty list for
  /// an item that had none, for [undo]. The snapshot is read inside the same
  /// transaction as the writes, so a sync apply cannot land between the read
  /// and the write. A tag in both sets ends up removed. An empty change
  /// writes nothing and returns an empty map.
  Future<Map<String, List<String>>> apply({
    required List<String> equipmentIds,
    required Set<String> addTagIds,
    required Set<String> removeTagIds,
  }) async {
    if (equipmentIds.isEmpty || (addTagIds.isEmpty && removeTagIds.isEmpty)) {
      return const {};
    }
    final prior = await _db.transaction(() async {
      final before = await _repository.getTagIdsByEquipment(equipmentIds);
      if (addTagIds.isNotEmpty) {
        await _repository.addTags(
          equipmentIds,
          addTagIds.toList(),
          notify: false,
        );
      }
      if (removeTagIds.isNotEmpty) {
        await _repository.removeTags(
          equipmentIds,
          removeTagIds.toList(),
          notify: false,
        );
      }
      return <String, List<String>>{
        for (final id in equipmentIds)
          id: List<String>.unmodifiable(before[id] ?? const <String>[]),
      };
    });
    SyncEventBus.notifyLocalChange();
    return prior;
  }

  /// Puts every item in [prior] back to exactly its snapshot tag set, in one
  /// transaction, then notifies once.
  ///
  /// An item deleted since [apply] is skipped and a tag deleted since is left
  /// out, so Undo never recreates a link to a row that is gone (the foreign
  /// keys would refuse it and roll back every other item's restore).
  Future<void> undo(Map<String, List<String>> prior) async {
    if (prior.isEmpty) return;
    await _db.transaction(() async {
      final itemRows =
          await (_db.selectOnly(_db.equipment)
                ..addColumns([_db.equipment.id])
                ..where(_db.equipment.id.isIn(prior.keys.toList())))
              .get();
      final liveItems = {for (final r in itemRows) r.read(_db.equipment.id)!};

      final snapshotTagIds = {for (final tags in prior.values) ...tags};
      final tagRows =
          await (_db.selectOnly(_db.tags)
                ..addColumns([_db.tags.id])
                ..where(_db.tags.id.isIn(snapshotTagIds.toList())))
              .get();
      final liveTags = {for (final r in tagRows) r.read(_db.tags.id)!};

      for (final entry in prior.entries) {
        if (!liveItems.contains(entry.key)) continue;
        await _repository.replaceTags(entry.key, [
          for (final tagId in entry.value)
            if (liveTags.contains(tagId)) tagId,
        ], notify: false);
      }
    });
    SyncEventBus.notifyLocalChange();
  }
}
