part of 'dive_repository_impl.dart';

/// Gear changes worked out without writing, from the same helpers and
/// expander the gear writes use, so a preview and the write agree.
extension DiveGearPreview on DiveRepository {
  /// The equipment ids [diveId] would carry after [bulkAddEquipment] adds
  /// [add] and [bulkRemoveEquipment] then removes [remove]: assemblies bring
  /// their active parts, and a removed item takes what is attached through
  /// it. Reads only, so a preview can show it before anything is written.
  Future<Set<String>> gearIdsAfter(
    String diveId, {
    List<String> add = const [],
    List<String> remove = const [],
  }) async {
    var rows = await _provenanceOf(diveId);
    if (add.isNotEmpty) {
      final index = await _loadComponentsIndex();
      final active = await _activeIdsAmong({
        for (final id in add) ...[id, ...index.descendantsOf(id)],
      });
      rows = GearExpander.expand(
        additions: [for (final id in add) (equipmentId: id, viaSetId: null)],
        index: index,
        existing: rows,
        isActive: active.contains,
      );
    }
    for (final id in remove) {
      rows = GearExpander.removeSubtree(rows, id);
    }
    return {for (final row in rows) row.equipmentId};
  }
}
