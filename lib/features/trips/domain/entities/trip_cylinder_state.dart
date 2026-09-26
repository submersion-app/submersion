import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

/// What the board says about a slot right now.
enum TripCylinderStatus {
  /// The last thing that happened was a fill, or a gauge reading near the
  /// working pressure.
  full,

  /// Used since the last fill, but above the empty line.
  partial,

  /// At or below the empty line; nobody dives this bottle again.
  empty,

  /// Nothing has happened to the slot yet.
  unknown,
}

/// A dive tank's use of a slot, lean: what the fold needs and nothing else.
/// [entryTime] is the dive's `dateTime`, in the wall-clock-as-UTC frame.
class TripCylinderTankUse extends Equatable {
  final String tankId;
  final String diveId;
  final DateTime entryTime;
  final double? startPressure;
  final double? endPressure;
  final GasMix gasMix;

  const TripCylinderTankUse({
    required this.tankId,
    required this.diveId,
    required this.entryTime,
    this.startPressure,
    this.endPressure,
    this.gasMix = const GasMix(),
  });

  @override
  List<Object?> get props => [
    tankId,
    diveId,
    entryTime,
    startPressure,
    endPressure,
    gasMix,
  ];
}

/// A slot with its derived state. Nothing here is stored; it is recomputed
/// from the ledger and the linked tanks on every read.
class TripCylinderState extends Equatable {
  final TripCylinder cylinder;

  /// Current pressure in bar; null when the last item left it unknown.
  final double? pressure;

  /// The mix the slot holds; null before the first fill with a mix.
  final GasMix? mix;

  /// The latest fill's bottle number, else the slot's own label.
  final String bottleLabel;
  final TripCylinderStatus status;
  final TripCylinderEvent? lastFill;

  /// When the last timeline item happened (fill, adjustment or dive).
  final DateTime? lastEventAt;

  /// Distinct dives that breathed from the slot.
  final int linkedDiveCount;

  const TripCylinderState({
    required this.cylinder,
    this.pressure,
    this.mix,
    required this.bottleLabel,
    required this.status,
    this.lastFill,
    this.lastEventAt,
    this.linkedDiveCount = 0,
  });

  @override
  List<Object?> get props => [
    cylinder,
    pressure,
    mix,
    bottleLabel,
    status,
    lastFill,
    lastEventAt,
    linkedDiveCount,
  ];
}
