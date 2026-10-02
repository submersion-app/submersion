import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';

// A leaf: equipment_providers reads tripGearIdsProvider, so this file must
// not import it back (trip_equipment_providers does, and re-exports the
// repository provider from here).

final tripEquipmentRepositoryProvider = Provider<TripEquipmentRepository>(
  (ref) => TripEquipmentRepository(),
);

/// The ids of the gear on a trip: packed through `trip_equipment` or on a
/// slot of its cylinder board, the same union as equipmentTripsProvider.
/// The trip's service alerts and scrubber margins cover only this gear and
/// the parts installed in it (issue #2727). Ids only: visibility is the
/// caller's, which reads the diver's own gear.
final tripGearIdsProvider = FutureProvider.family<Set<String>, String>((
  ref,
  tripId,
) async {
  final packs = ref.watch(tripEquipmentRepositoryProvider);
  final slots = ref.watch(tripCylinderRepositoryProvider);
  ref.invalidateSelfWhen(packs.watchChanges());
  // Slots only: the board's wider stream fires on every dive and tank
  // write, which would re-run each open trip's alerts for nothing.
  ref.invalidateSelfWhen(slots.watchSlotChanges());
  return {
    ...await packs.equipmentIdsForTrip(tripId),
    ...await slots.equipmentIdsForTrip(tripId),
  };
});
