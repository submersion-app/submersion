import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// A tank as observed on a historical dive (weight prediction input).
class ObservedTank extends Equatable {
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? material;
  final String? presetName;

  const ObservedTank({
    this.volumeL,
    this.workingPressureBar,
    this.material,
    this.presetName,
  });

  @override
  List<Object?> get props => [
    volumeL,
    workingPressureBar,
    material,
    presetName,
  ];
}

/// One historical dive with recorded weights: a training row for the
/// weight prediction engine.
///
/// Pure data; assembled from the database by the weight_planner feature's
/// WeightHistoryRepository.
class WeightObservation extends Equatable {
  final String diveId;
  final DateTime diveDateTime;
  final WaterType? waterType;

  /// Total lead carried: sum of dive_weights rows, or the legacy
  /// dives.weightAmount when no typed entries exist.
  final double carriedKg;

  /// WeightType.name -> kg; empty when only the legacy scalar was recorded.
  final Map<String, double> placement;

  final List<String> equipmentIds;
  final List<ObservedTank> tanks;

  /// WeightingFeedback.name, or null when unrated.
  final String? feedback;
  final double? feedbackKg;

  const WeightObservation({
    required this.diveId,
    required this.diveDateTime,
    this.waterType,
    required this.carriedKg,
    this.placement = const {},
    this.equipmentIds = const [],
    this.tanks = const [],
    this.feedback,
    this.feedbackKg,
  });

  @override
  List<Object?> get props => [
    diveId,
    diveDateTime,
    waterType,
    carriedKg,
    placement,
    equipmentIds,
    tanks,
    feedback,
    feedbackKg,
  ];
}
