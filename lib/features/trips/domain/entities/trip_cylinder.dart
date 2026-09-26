import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// One cylinder slot the diver holds on a trip: one of the N bottles in the
/// truck, not a specific bottle. A rental slot stands alone; an owned
/// cylinder links through [equipmentId] and copies its specs here at
/// creation. The operator's number for the bottle currently in the slot
/// rides on each fill event, so a swap at the fill station is one event and
/// the board shows N chips all week.
///
/// Metric: [volume] in liters, [workingPressure] in bar. Shown in the active
/// diver's units at display time.
class TripCylinder extends Equatable {
  final String id;
  final String tripId;

  /// The owned cylinder in this slot, if any.
  final String? equipmentId;

  /// The slot's name, or the owned bottle's mark: "Truck 3", "My HP100".
  final String label;
  final double? volume;
  final double? workingPressure;
  final TankMaterial? material;

  /// The preset the slot was made from, when it was.
  final String? presetName;
  final int sortOrder;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripCylinder({
    required this.id,
    required this.tripId,
    this.equipmentId,
    this.label = '',
    this.volume,
    this.workingPressure,
    this.material,
    this.presetName,
    this.sortOrder = 0,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  TripCylinder copyWith({
    String? id,
    String? tripId,
    Object? equipmentId = _undefined,
    String? label,
    Object? volume = _undefined,
    Object? workingPressure = _undefined,
    Object? material = _undefined,
    Object? presetName = _undefined,
    int? sortOrder,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripCylinder(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      equipmentId: equipmentId == _undefined
          ? this.equipmentId
          : equipmentId as String?,
      label: label ?? this.label,
      volume: volume == _undefined ? this.volume : volume as double?,
      workingPressure: workingPressure == _undefined
          ? this.workingPressure
          : workingPressure as double?,
      material: material == _undefined
          ? this.material
          : material as TankMaterial?,
      presetName: presetName == _undefined
          ? this.presetName
          : presetName as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    equipmentId,
    label,
    volume,
    workingPressure,
    material,
    presetName,
    sortOrder,
    notes,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
