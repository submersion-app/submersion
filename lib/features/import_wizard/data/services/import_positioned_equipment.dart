import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';

/// Re-chooses equipment for the dives [result] created that a GPS track has
/// just positioned (issue #3704), so each gets the set its position calls
/// for, as if the position had been known when it was written. A download
/// may swap the default set for a geofenced one; a file import only fills
/// a dive with no gear, since the file may carry the diver's own choice.
///
/// Only dives this import created: a planned dive it filled keeps the
/// diver's plan, and an existing dive it merged into keeps its gear.
Future<void> reequipPositionedDives(
  DiveEquipmentDefaulter defaulter,
  UnifiedImportResult result, {
  required List<String> positionedDiveIds,
  required ImportSourceType sourceType,
}) async {
  if (positionedDiveIds.isEmpty) return;
  final planned = {for (final o in result.fillOutcomes) o.diveId};
  final created = {
    ...result.importedDiveIds,
    for (final outcome in result.diverOutcomes) ...outcome.diveIds,
  }.difference(planned);
  await defaulter.applyForPositionedDives([
    for (final id in positionedDiveIds)
      if (created.contains(id)) id,
  ], replaceDefault: !sourceType.mayBringGear);
}
