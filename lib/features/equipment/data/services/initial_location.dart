import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';

final _log = LoggerService.forClass(EquipmentLocationMoveRepository);

/// Records a new item's first location, chosen on the new item form.
/// Returns false instead of throwing when the write fails: the item itself
/// is saved by then, so the form must not report a failed save (a retry
/// would create the item twice). The caller tells the diver the location
/// was not set.
Future<bool> recordInitialLocation({
  required EquipmentLocationMoveRepository moves,
  required String equipmentId,
  required String locationId,
}) async {
  try {
    await moves.recordMoves(
      equipmentIds: [equipmentId],
      locationId: locationId,
      movedAt: DateTime.now(),
    );
    return true;
  } catch (e, stackTrace) {
    _log.error(
      'Failed to record the first location of $equipmentId',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}
