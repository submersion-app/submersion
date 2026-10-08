import 'package:submersion/features/dive_import/data/services/import_equipment_tag_linker.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';

/// Records imported equipment's location (v268). Each item map's
/// `locationName` resolves to one of the diver's places by name, ignoring
/// case (an active place before an archived one), or to a new place of kind
/// other; the item then gets one move there, dated now. An item already at
/// that place gets none, so re-importing a file adds no history. Items are
/// keyed exactly as [ImportEquipmentTagLinker] keys them. The Submersion
/// equipment CSV reaches it through each item map's `locationName`.
class ImportEquipmentLocationLinker {
  const ImportEquipmentLocationLinker({
    required this.places,
    required this.moves,
  });

  final EquipmentLocationRepository places;
  final EquipmentLocationMoveRepository moves;

  /// [items] are the file's equipment maps; [equipmentIdMapping] maps the
  /// file's ids (or an id-less item's unique name) to local ids. New places
  /// belong to [diverId].
  Future<void> link({
    required List<Map<String, dynamic>> items,
    required Map<String, String> equipmentIdMapping,
    required String? diverId,
  }) async {
    // Most imports (UDDF, dive logs, an older CSV) carry no location at
    // all: those touch no location table.
    bool named(Map<String, dynamic> data) =>
        data['locationName'] is String &&
        (data['locationName'] as String).trim().isNotEmpty;
    if (!items.any(named)) return;
    final idlessNameCounts = ImportEquipmentTagLinker.countIdlessEquipmentNames(
      items,
    );
    final current = await moves.getCurrentLocationIds();
    // One lookup per distinct name, so a file naming the same new place on
    // many rows creates it once.
    final resolved = <String, String>{};
    final now = DateTime.now();
    for (final data in items) {
      final name = data['locationName'];
      if (name is! String || name.trim().isEmpty) continue;
      final uddfId = data['uddfId'] as String?;
      final itemName = data['name'] as String?;
      final key = uddfId ?? (idlessNameCounts[itemName] == 1 ? itemName : null);
      final equipmentId = key == null ? null : equipmentIdMapping[key];
      if (equipmentId == null) continue;
      final placeId = resolved[name.trim().toLowerCase()] ??=
          (await places.findOrCreateByName(diverId: diverId, name: name)).id;
      if (current[equipmentId] == placeId) continue;
      await moves.recordMoves(
        equipmentIds: [equipmentId],
        locationId: placeId,
        movedAt: now,
      );
      current[equipmentId] = placeId;
    }
  }
}
