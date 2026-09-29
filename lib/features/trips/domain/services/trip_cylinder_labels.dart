import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';

/// A slot as a dive tank names it: its label, and the bottle it held at the
/// dive (the slot's own label when no fill before it named one, which the
/// tank line leaves out).
typedef TripCylinderTankLabel = ({String label, String? bottle});

/// Pure. Each slot's label and the bottle it held at [atMillis], read from
/// the same fold the board uses, so the two never name different bottles:
/// a refill that names none keeps the earlier bottle, and fills at one
/// instant tie as the board ties them. A fill at the dive's own minute was
/// for that dive. So a bottle swapped later in the week does not rename an
/// earlier dive's tank.
Map<String, TripCylinderTankLabel> tripCylinderLabelsAt({
  required List<TripCylinder> cylinders,
  required Map<String, List<TripCylinderEvent>> eventsBySlot,
  required int atMillis,
}) => {
  for (final s in foldCylinderStatesAt(
    cylinders: cylinders,
    eventsBySlot: eventsBySlot,
    // The bottle comes from fills alone; dives never change it.
    usesBySlot: const {},
    atMillis: atMillis,
  ))
    s.cylinder.id: (label: s.cylinder.label, bottle: s.bottleLabel),
};
