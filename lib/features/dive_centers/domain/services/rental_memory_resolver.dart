import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';

/// What the diver's most recent dive at a center says about the rental rig
/// they used (issue #2075): the lead they carried, how it felt, and the
/// cylinders. Nothing here is stored; it is read off the hydrated dive every
/// time, so it can never drift from the dive itself.
///
/// Build it only from the fully hydrated dive (`DiveRepository.getDiveById`).
/// The lean analysis hydration leaves `weights` empty, which would make every
/// last dive look weightless.
class LastDiveAtCenter extends Equatable {
  final String diveId;
  final DateTime dateTime;
  final List<DiveWeight> weights;
  final WeightingFeedback? weightingFeedback;
  final double? weightingFeedbackKg;
  final List<DiveTank> tanks;

  const LastDiveAtCenter({
    required this.diveId,
    required this.dateTime,
    required this.weights,
    required this.weightingFeedback,
    required this.weightingFeedbackKg,
    required this.tanks,
  });

  factory LastDiveAtCenter.fromDive(Dive dive) => LastDiveAtCenter(
    diveId: dive.id,
    dateTime: dive.dateTime,
    weights: List.unmodifiable(dive.weights),
    weightingFeedback: dive.weightingFeedback,
    weightingFeedbackKg: dive.weightingFeedbackKg,
    tanks: List.unmodifiable(dive.tanks),
  );

  double get totalLeadKg => weights.fold(0.0, (sum, w) => sum + w.amountKg);

  /// The weights as rows for a new dive, under fresh ids so the copies are
  /// independent of the source dive once applied.
  List<DiveWeight> weightsForNewDive({
    required String diveId,
    required String Function() newId,
  }) => [
    for (final w in weights)
      DiveWeight(
        id: newId(),
        diveId: diveId,
        weightType: w.weightType,
        amountKg: w.amountKg,
        notes: w.notes,
      ),
  ];

  /// The cylinders as rows for a new dive: the rig (size, rating, preset,
  /// material, mix, role, order) travels; the pressures do not, because the
  /// new dive has not happened yet, and neither do the computer, transmitter
  /// and owned-gear links, which describe the old dive's hardware.
  List<DiveTank> tanksForNewDive({
    required String Function() newId,
    required double startPressure,
    required double endPressure,
  }) => [
    for (final t in tanks)
      DiveTank(
        id: newId(),
        name: t.name,
        volume: t.volume,
        workingPressure: t.workingPressure,
        startPressure: startPressure,
        endPressure: endPressure,
        gasMix: t.gasMix,
        role: t.role,
        material: t.material,
        order: t.order,
        presetName: t.presetName,
        decoSwitchDepth: t.decoSwitchDepth,
        isTravelGas: t.isTravelGas,
      ),
  ];

  @override
  List<Object?> get props => [
    diveId,
    dateTime,
    weights,
    weightingFeedback,
    weightingFeedbackKg,
    tanks,
  ];
}
