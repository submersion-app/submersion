import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

/// Builds and refreshes a [ScooterSpec] from a DPV equipment item.
///
/// The spec is a snapshot so a plan stays computable after the item is
/// deleted; [overlay] refreshes the snapshot from the live item so a corrected
/// burn time on the equipment page reaches every plan that uses the scooter.
class ScooterSpecResolver {
  const ScooterSpecResolver();

  /// A spec from [item], or null when the item lacks a speed or a burn time.
  ScooterSpec? fromEquipment(EquipmentItem item) {
    final speed = item.dpvSpeedMps;
    final burnHours = item.dpvBurnTimeHours;
    if (speed == null || burnHours == null) return null;
    return ScooterSpec(
      equipmentId: item.id,
      name: item.name,
      ratedSpeedMps: speed,
      burnTimeSeconds: (burnHours * 3600).round(),
      towSpeedFactor: item.dpvTowSpeedFactor ?? kDefaultTowSpeedFactor,
      towBurnFactor: item.dpvTowBurnFactor ?? kDefaultTowBurnFactor,
    );
  }

  /// [stored] refreshed from [live]. Attributes the item carries win; ones it
  /// lacks keep the snapshot. A null item (deleted) or a manual scooter (no
  /// equipment id) returns [stored] unchanged.
  ScooterSpec overlay(ScooterSpec stored, EquipmentItem? live) {
    if (live == null || stored.equipmentId == null) return stored;
    if (live.id != stored.equipmentId) return stored;
    final burnHours = live.dpvBurnTimeHours;
    return stored.copyWith(
      name: live.name,
      ratedSpeedMps: live.dpvSpeedMps,
      burnTimeSeconds: burnHours == null ? null : (burnHours * 3600).round(),
      towSpeedFactor: live.dpvTowSpeedFactor,
      towBurnFactor: live.dpvTowBurnFactor,
    );
  }
}
