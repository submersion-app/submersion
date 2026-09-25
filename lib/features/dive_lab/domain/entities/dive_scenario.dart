import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';

/// A saved "what if" on a logged dive: inputs only; results are recomputed.
class DiveScenario extends Equatable {
  const DiveScenario({
    required this.id,
    required this.diveId,
    required this.name,
    this.notes,
    required this.branchSeconds,
    required this.mode,
    this.interventions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String diveId;
  final String name;
  final String? notes;

  /// Runtime seconds on the dive's primary profile where the timelines part.
  final int branchSeconds;
  final ScenarioMode mode;
  final List<ScenarioIntervention> interventions;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The mode the engine actually runs: a path-changing intervention forces
  /// re-plan regardless of the stored mode.
  ScenarioMode get effectiveMode =>
      interventions.any((i) => i.requiresReplan) ? ScenarioMode.replan : mode;

  /// Whether the counterfactual aborts the dive at the branch point.
  bool get abortsAtBranch =>
      effectiveMode == ScenarioMode.replan &&
      interventions.any((i) => i.impliesAscendNow);

  DiveScenario copyWith({
    String? id,
    String? diveId,
    String? name,
    String? notes,
    bool clearNotes = false,
    int? branchSeconds,
    ScenarioMode? mode,
    List<ScenarioIntervention>? interventions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiveScenario(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      name: name ?? this.name,
      notes: clearNotes ? null : (notes ?? this.notes),
      branchSeconds: branchSeconds ?? this.branchSeconds,
      mode: mode ?? this.mode,
      interventions: interventions ?? this.interventions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    name,
    notes,
    branchSeconds,
    mode,
    interventions,
    createdAt,
    updatedAt,
  ];
}

enum ScenarioValidationError { duplicateKind, shiftAscentWithAbort }

/// Composition rules from the spec: at most one intervention per kind, and a
/// shifted ascent cannot combine with a kind that aborts the dive.
List<ScenarioValidationError> validateInterventions(
  List<ScenarioIntervention> interventions,
) {
  final errors = <ScenarioValidationError>[];
  final kinds = <InterventionKind>{};
  for (final i in interventions) {
    if (!kinds.add(i.kind)) {
      errors.add(ScenarioValidationError.duplicateKind);
      break;
    }
  }
  final hasShift = interventions.any(
    (i) => i.kind == InterventionKind.shiftAscent,
  );
  final hasAbort = interventions.any((i) => i.impliesAscendNow);
  if (hasShift && hasAbort) {
    errors.add(ScenarioValidationError.shiftAscentWithAbort);
  }
  return errors;
}
