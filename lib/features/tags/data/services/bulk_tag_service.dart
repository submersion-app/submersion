import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/existing_row_ids.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';

/// Puts tags on and takes them off many items of one scope at once, with
/// undo (issue #1970), as BulkEquipmentTagService does for equipment.
///
/// Only junction rows change. No item row is written or marked pending, so
/// an edit made to an item between Apply and Undo survives both, and a stale
/// whole-item snapshot can never beat a peer's newer edit (#1769).
class BulkTagService {
  BulkTagService(TagLinkRepository repository, {required String itemTable})
    : _repository = repository,
      _itemTable = itemTable;

  final TagLinkRepository _repository;

  /// The table holding the scope's items, which Undo checks for survivors.
  final String _itemTable;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Puts [addTagIds] on every item in [itemIds] and takes [removeTagIds]
  /// off every one, in one transaction, then notifies once.
  ///
  /// Returns each item's tag ids as they were before, with an empty list for
  /// an item that had none, for [undo]. The snapshot is read inside the same
  /// transaction as the writes, so a sync apply cannot land between the read
  /// and the write. A tag in both sets ends up removed. An empty change
  /// writes nothing and returns an empty map.
  Future<Map<String, List<String>>> apply({
    required List<String> itemIds,
    required Set<String> addTagIds,
    required Set<String> removeTagIds,
  }) async {
    if (itemIds.isEmpty || (addTagIds.isEmpty && removeTagIds.isEmpty)) {
      return const {};
    }
    final prior = await _db.transaction(() async {
      final before = await _repository.getTagIdsByItem(itemIds);
      if (addTagIds.isNotEmpty) {
        await _repository.addTags(itemIds, addTagIds.toList(), notify: false);
      }
      if (removeTagIds.isNotEmpty) {
        await _repository.removeTags(
          itemIds,
          removeTagIds.toList(),
          notify: false,
        );
      }
      return <String, List<String>>{
        for (final id in itemIds)
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
      final itemTable = _db.allTables.firstWhere(
        (t) => t.actualTableName == _itemTable,
      );
      final liveItems = await existingRowIds(_db, itemTable, prior.keys);
      final liveTags = await existingRowIds(_db, _db.tags, {
        for (final tags in prior.values) ...tags,
      });
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
