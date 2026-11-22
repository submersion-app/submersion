import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_key_adoption.dart';

const _log = LoggerService('TransmitterKeyAfterSave');

/// What follows a committed save, each step best effort, in order: the
/// fold of a taken-over placeholder (its own History entry), the findings
/// refresh (the dropout findings read serials through the transmitter
/// link and are stored, read without the engine), and the serial copy
/// onto the item.
Future<void> afterTransmitterKeySaved(
  TransmitterKeyWrite written, {
  required String equipmentId,
  required String? serialForItem,
  required EquipmentRepository equipment,
  required EquipmentListNotifier equipmentList,
}) async {
  await foldTakenOverPlaceholder(written);
  scheduleConditionFindingsRefresh({equipmentId});
  if (serialForItem != null) {
    await _fillItemSerial(
      serialForItem,
      equipmentId: equipmentId,
      equipment: equipment,
      equipmentList: equipmentList,
    );
  }
}

/// Writes [serial] onto the item, which had none at load. Through the list
/// notifier, as the equipment editor saves, so the lists refresh. The item
/// is read afresh, not from the copy read at load: a sync, or the fold of a
/// placeholder, may have given it a serial since, which stays, and the
/// write must not put back fields they changed. A failure is logged and
/// swallowed: the key is already saved.
Future<void> _fillItemSerial(
  String serial, {
  required String equipmentId,
  required EquipmentRepository equipment,
  required EquipmentListNotifier equipmentList,
}) async {
  try {
    final gear = await equipment.getEquipmentById(equipmentId);
    if (gear == null || normalizeTransmitterSerial(gear.serialNumber) != null) {
      return;
    }
    await equipmentList.updateEquipment(gear.copyWith(serialNumber: serial));
  } catch (e, stackTrace) {
    _log.warning(
      'Could not copy the serial onto the transmitter item',
      error: e,
      stackTrace: stackTrace,
    );
  }
}
