import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

/// A dive tank breathed from one of the trip's slots, as the record reads
/// it: the lean facts plus the diver, the site and the tank's size.
/// [entryTime] is wall-clock-as-UTC, the frame every dive time uses.
class TripGasRecordTank extends Equatable {
  const TripGasRecordTank({
    required this.tankId,
    required this.diveId,
    required this.entryTime,
    this.diverId,
    this.diverName,
    this.siteName,
    this.tankOrder = 0,
    this.volume,
    this.startPressure,
    this.endPressure,
    this.gasMix = const GasMix(),
    required this.tripCylinderId,
  });

  final String tankId;
  final String diveId;
  final DateTime entryTime;
  final String? diverId;
  final String? diverName;
  final String? siteName;
  final int tankOrder;

  /// Water volume in litres.
  final double? volume;
  final double? startPressure;
  final double? endPressure;
  final GasMix gasMix;
  final String tripCylinderId;

  @override
  List<Object?> get props => [
    tankId,
    diveId,
    entryTime,
    diverId,
    diverName,
    siteName,
    tankOrder,
    volume,
    startPressure,
    endPressure,
    gasMix,
    tripCylinderId,
  ];
}

/// A tank on one of the trip's dives that breathes from no slot of the
/// trip: the record's gaps.
class TripUnlinkedTank extends Equatable {
  const TripUnlinkedTank({
    required this.tankId,
    required this.diveId,
    required this.entryTime,
    this.diverId,
    this.diverName,
    this.siteName,
    this.tankOrder = 0,
    this.computerId,
  });

  final String tankId;
  final String diveId;
  final DateTime entryTime;
  final String? diverId;
  final String? diverName;
  final String? siteName;
  final int tankOrder;

  /// The computer the tank row came from; null is the dive's primary
  /// source. On a dive from two computers it tells their rows apart.
  final String? computerId;

  @override
  List<Object?> get props => [
    tankId,
    diveId,
    entryTime,
    diverId,
    diverName,
    siteName,
    tankOrder,
    computerId,
  ];
}

/// One row of the record: a tank, its slot, and the fill in effect when the
/// dive started.
class TripGasRecordRow extends Equatable {
  const TripGasRecordRow({
    required this.tank,
    required this.cylinder,
    required this.bottleLabel,
    this.fill,
    this.fillPressure,
    this.litres,
  });

  final TripGasRecordTank tank;
  final TripCylinder cylinder;

  /// The bottle the slot held (the slot's own label when no fill named one).
  final String bottleLabel;
  final TripCylinderEvent? fill;

  /// The fill's reading, else the slot's working pressure; null with no
  /// fill before the dive.
  final double? fillPressure;

  /// Gas breathed in free litres; null when the tank has no volume or a
  /// pressure is missing.
  final double? litres;

  /// The bottle a fill named, or null when [bottleLabel] is only the slot's
  /// label, which the board's lines leave out the same way.
  String? get namedBottle => bottleLabel == cylinder.label ? null : bottleLabel;

  GasMix? get orderedMix => fill?.orderedMix;
  GasMix? get analyzedMix => fill?.analyzedMix;
  String? get diveCenterId => fill?.diveCenterId;

  @override
  List<Object?> get props => [
    tank,
    cylinder,
    bottleLabel,
    fill,
    fillPressure,
    litres,
  ];
}

/// One slot's totals.
class TripGasRecordSlotTotal extends Equatable {
  const TripGasRecordSlotTotal({
    required this.cylinder,
    required this.dives,
    this.litres,
    required this.leftOut,
  });

  final TripCylinder cylinder;

  /// Distinct dives that breathed from the slot.
  final int dives;

  /// Litres over the rows that have a figure; null when no row has one, so
  /// an unmeasured slot never reads as 0 L.
  final double? litres;

  /// Distinct dives with a row that has no figure, left out of [litres]
  /// (counted as dives, as the header says).
  final int leftOut;

  @override
  List<Object?> get props => [cylinder, dives, litres, leftOut];
}

/// The trip's gas record (spec "Phase 3 gas record").
class TripGasRecord extends Equatable {
  const TripGasRecord({
    required this.rows,
    required this.slots,
    required this.fillsLogged,
    required this.costs,
    required this.packageFills,
    required this.unlinked,
    required this.multipleDivers,
  });

  final List<TripGasRecordRow> rows;
  final List<TripGasRecordSlotTotal> slots;
  final int fillsLogged;

  /// Non-package fill costs by currency, largest first.
  final List<MapEntry<String, double>> costs;
  final int packageFills;
  final List<TripUnlinkedTank> unlinked;

  /// More than one diver logged the tanks, so each row names its diver.
  final bool multipleDivers;

  @override
  List<Object?> get props => [
    rows,
    slots,
    fillsLogged,
    [for (final c in costs) '${c.key}:${c.value}'],
    packageFills,
    unlinked,
    multipleDivers,
  ];
}
