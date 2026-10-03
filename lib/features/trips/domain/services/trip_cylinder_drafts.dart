import 'dart:math';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

/// The board position after the last slot: deletions leave gaps, so the
/// count of slots could land a new one above an existing one.
int nextTripCylinderSortOrder(List<TripCylinder> existing) =>
    existing.isEmpty ? 0 : existing.map((c) => c.sortOrder).reduce(max) + 1;

/// A slot for one of the diver's own cylinders: linked to the item, named
/// by its mark (else its name), carrying the item's specs. Shared by the
/// Cylinders sheet and the Gear tab's Add (#2845).
TripCylinder tripCylinderDraftFromEquipment(
  EquipmentItem item, {
  required String tripId,
  required int sortOrder,
  required DateTime now,
}) {
  final mark = item.identifier?.trim() ?? '';
  return TripCylinder(
    id: '',
    tripId: tripId,
    equipmentId: item.id,
    label: mark.isEmpty ? item.name : mark,
    volume: item.volumeL,
    workingPressure: item.workingPressureBar,
    material: item.tankMaterial,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  );
}
