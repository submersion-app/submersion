import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

/// A slot as a dive tank names it: its label, and the bottle number of the
/// fill in effect at the dive (null when no fill before it named one).
typedef TripCylinderTankLabel = ({String label, String? bottle});

/// Pure. Each slot's label and the bottle it held at [atMillis]: the bottle
/// number of its last fill at or before that instant, the same ordering the
/// fold uses (a fill at the dive's own minute was for that dive). So a
/// bottle swapped later in the week does not rename an earlier dive's tank.
Map<String, TripCylinderTankLabel> tripCylinderLabelsAt({
  required List<TripCylinder> cylinders,
  required Map<String, List<TripCylinderEvent>> eventsBySlot,
  required int atMillis,
}) => {
  for (final c in cylinders)
    c.id: (
      label: c.label,
      bottle: (eventsBySlot[c.id] ?? const <TripCylinderEvent>[])
          .where(
            (e) =>
                e.kind == TripCylinderEventKind.fill &&
                e.occurredAt.millisecondsSinceEpoch <= atMillis,
          )
          .lastOrNull
          ?.bottleLabel,
    ),
};
