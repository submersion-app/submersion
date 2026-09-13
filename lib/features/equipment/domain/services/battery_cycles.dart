import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

/// Gear that runs on a battery, and so is charged (or swapped) around each
/// dive. Everything else counts no [ExposureUnit.cycles] unless the diver
/// asks for a cycles clock on it (see [accruesBatteryCycles]).
const Set<EquipmentType> kBatteryPoweredTypes = {
  EquipmentType.battery,
  EquipmentType.light,
  EquipmentType.dpv,
  EquipmentType.computer,
  EquipmentType.transmitter,
  EquipmentType.rebreather,
  EquipmentType.camera,
  EquipmentType.strobe,
};

/// Whether an item of [type] counts battery cycles: a powered type always
/// does, and any other item does once it has a clock that counts cycles
/// (a heated vest filed as `other`, say), or that clock could never come
/// due. A clock counts only as the service engine would read it: enabled,
/// with a known kind, and a cycles interval of its own or its kind's.
bool accruesBatteryCycles({
  required EquipmentType type,
  required Iterable<ServiceSchedule> schedules,
  required Map<String, ServiceKind> kindsById,
}) {
  if (kBatteryPoweredTypes.contains(type)) return true;
  for (final schedule in schedules) {
    if (!schedule.enabled) continue;
    final kind = kindsById[schedule.serviceKindId];
    if (kind == null) continue;
    final interval = schedule.intervalFor(ExposureUnit.cycles, kind);
    if (interval != null && interval > 0) return true;
  }
  return false;
}
