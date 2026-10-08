import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_gear_scope.dart';

/// A trip's packed gear as the Gear tab lists it (#2845): [packed] is the
/// gear that is not a cylinder, and [unslottedTanks] the owned tanks packed
/// with no slot on the board. Each is in the order given.
typedef TripGearSplit = ({
  List<EquipmentItem> packed,
  List<EquipmentItem> unslottedTanks,
});

/// Splits [gear] against the board's [slots]. An owned cylinder on the
/// board is listed by its slot alone, so its packed link (if any) is left
/// out ([packedOffBoard], #2874). A tank packed with no slot (the old Use
/// set packed tanks as gear, issue #2873) is still a cylinder, waiting to
/// be put on the board, not packed gear.
TripGearSplit splitTripGear(
  List<EquipmentItem> gear,
  List<TripCylinder> slots,
) {
  final unslotted = packedOffBoard(gear, slots);
  return (
    packed: [
      for (final i in unslotted)
        if (i.type != EquipmentType.tank) i,
    ],
    unslottedTanks: [
      for (final i in unslotted)
        if (i.type == EquipmentType.tank) i,
    ],
  );
}
