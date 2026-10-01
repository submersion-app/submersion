import 'package:clock/clock.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_gear_ids_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

export 'package:submersion/features/trips/presentation/providers/trip_gear_ids_providers.dart'
    show tripEquipmentRepositoryProvider;

/// The gear packed for a trip that the diver can see (owner or sharee),
/// by name (spec section 10.8).
final tripGearProvider = FutureProvider.family<List<EquipmentItem>, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(tripEquipmentRepositoryProvider);
  final equipment = ref.watch(equipmentRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  ref.invalidateSelfWhen(equipment.watchEquipmentChanges());
  // Visibility comes and goes with a share row (issue #2046).
  ref.invalidateSelfWhen(
    ref.read(equipmentShareRepositoryProvider).watchChanges(),
  );
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  var ids = await repository.equipmentIdsForTrip(tripId);
  if (diverId != null) {
    ids = (await equipment.visibleIdsAmong(ids, diverId)).toList();
  }
  final items = await equipment.getEquipmentByIds(ids);
  return [...items]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

/// A trip an item is on: packed through `trip_equipment`, a trip gas slot,
/// or both (decided 2026-09-29).
class PackedTrip {
  const PackedTrip({
    required this.trip,
    required this.packed,
    required this.slot,
  });

  final Trip trip;

  /// Packed through `trip_equipment`: the passport can unpack it.
  final bool packed;

  /// A slot on the trip's cylinder board, which the board owns.
  final bool slot;
}

/// In progress first, then upcoming by start, then past by most recent end.
List<PackedTrip> rankPackedTrips(List<PackedTrip> trips, DateTime now) {
  int group(Trip t) => t.containsDate(now) ? 0 : (t.startsAfter(now) ? 1 : 2);
  return [...trips]..sort((a, b) {
    final ga = group(a.trip);
    final gb = group(b.trip);
    if (ga != gb) return ga.compareTo(gb);
    return ga == 2
        ? b.trip.endDate.compareTo(a.trip.endDate)
        : a.trip.startDate.compareTo(b.trip.startDate);
  });
}

/// The trips [equipmentId] is on, among the trips the diver can see, ranked
/// for the passport's Trip card.
final equipmentTripsProvider = FutureProvider.family<List<PackedTrip>, String>((
  ref,
  equipmentId,
) async {
  final packs = ref.watch(tripEquipmentRepositoryProvider);
  final slots = ref.watch(tripCylinderRepositoryProvider);
  ref.invalidateSelfWhen(packs.watchChanges());
  ref.invalidateSelfWhen(slots.watchTripCylinderChanges());
  final trips = await ref.watch(allTripsProvider.future);
  final packed = await packs.tripIdsForEquipment(equipmentId);
  final slotted = await slots.tripIdsForEquipment(equipmentId);
  return rankPackedTrips([
    for (final trip in trips)
      if (packed.contains(trip.id) || slotted.contains(trip.id))
        PackedTrip(
          trip: trip,
          packed: packed.contains(trip.id),
          slot: slotted.contains(trip.id),
        ),
  ], clock.now());
});
