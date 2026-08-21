import 'package:equatable/equatable.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/services/remaining_bottom_compiler.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';

/// The scenario being explored on the lab page; ephemeral until saved.
class LabDraft extends Equatable {
  const LabDraft({
    this.branchSeconds,
    this.mode = ScenarioMode.replay,
    this.interventions = const [],
    this.scenarioId,
    this.name,
  });

  /// Null until the page seeds the default branch.
  final int? branchSeconds;
  final ScenarioMode mode;
  final List<ScenarioIntervention> interventions;

  /// The saved scenario this draft edits; null for an unsaved draft.
  final String? scenarioId;

  /// The saved name; null until saved.
  final String? name;

  bool get isSeeded => branchSeconds != null;

  bool get modeForced => interventions.any((i) => i.requiresReplan);

  ScenarioMode get effectiveMode => modeForced ? ScenarioMode.replan : mode;

  DiveScenario toScenario(String diveId) => DiveScenario(
    id: scenarioId ?? 'draft',
    diveId: diveId,
    name: name ?? 'draft',
    branchSeconds: branchSeconds ?? 0,
    mode: mode,
    interventions: interventions,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  LabDraft copyWith({
    int? branchSeconds,
    ScenarioMode? mode,
    List<ScenarioIntervention>? interventions,
    String? scenarioId,
    String? name,
  }) => LabDraft(
    branchSeconds: branchSeconds ?? this.branchSeconds,
    mode: mode ?? this.mode,
    interventions: interventions ?? this.interventions,
    scenarioId: scenarioId ?? this.scenarioId,
    name: name ?? this.name,
  );

  @override
  List<Object?> get props => [
    branchSeconds,
    mode,
    interventions,
    scenarioId,
    name,
  ];
}

class LabDraftNotifier extends StateNotifier<LabDraft> {
  LabDraftNotifier() : super(const LabDraft());

  /// Sets the branch once; later calls are ignored so a resolved default
  /// never overwrites a branch the diver already moved.
  void seedBranch(int seconds) {
    if (state.isSeeded) return;
    state = state.copyWith(branchSeconds: seconds < 0 ? 0 : seconds);
  }

  void setBranchSeconds(int seconds, {required int maxSeconds}) {
    state = state.copyWith(branchSeconds: seconds.clamp(0, maxSeconds));
  }

  void nudgeBranch(int deltaSeconds, {required int maxSeconds}) {
    setBranchSeconds(
      (state.branchSeconds ?? 0) + deltaSeconds,
      maxSeconds: maxSeconds,
    );
  }

  /// Ignored while a path-changing intervention forces re-plan.
  void setMode(ScenarioMode mode) {
    if (state.modeForced) return;
    state = state.copyWith(mode: mode);
  }

  /// Adds [intervention], replacing any of the same kind; a path-changing
  /// kind flips the mode to re-plan.
  void addIntervention(ScenarioIntervention intervention) {
    final others = state.interventions
        .where((i) => i.kind != intervention.kind)
        .toList();
    state = state.copyWith(
      interventions: [...others, intervention],
      mode: intervention.requiresReplan ? ScenarioMode.replan : null,
    );
  }

  void removeIntervention(InterventionKind kind) {
    state = state.copyWith(
      interventions: state.interventions.where((i) => i.kind != kind).toList(),
    );
  }

  void clearInterventions() {
    state = state.copyWith(interventions: const []);
  }

  /// Replaces the draft with a saved scenario (authoritative, even when the
  /// default branch was already seeded).
  void loadScenario(DiveScenario scenario) {
    state = LabDraft(
      branchSeconds: scenario.branchSeconds,
      mode: scenario.mode,
      interventions: scenario.interventions,
      scenarioId: scenario.id,
      name: scenario.name,
    );
  }

  /// Records that the draft now edits the saved scenario [id].
  void markSaved(String id, String name) {
    state = state.copyWith(scenarioId: id, name: name);
  }
}

final labDraftProvider =
    StateNotifierProvider.family<LabDraftNotifier, LabDraft, String>(
      (ref, diveId) => LabDraftNotifier(),
    );

/// The branch the lab opens at: the detail chart's tracking cursor if the
/// diver had one, else the start of the final ascent, else the deepest
/// sample.
final labDefaultBranchProvider = FutureProvider.family<int, String>((
  ref,
  diveId,
) async {
  final inputs = await ref.watch(labRequestInputsProvider(diveId).future);
  if (inputs == null || inputs.timestamps.isEmpty) return 0;
  final tracking = ref.read(profileTrackingIndexProvider(diveId));
  if (tracking != null &&
      tracking >= 0 &&
      tracking < inputs.timestamps.length) {
    return inputs.timestamps[tracking];
  }
  final analysis = await ref.watch(profileAnalysisProvider(diveId).future);
  final end = finalAscentStartIndex(
    depths: inputs.depths,
    timestamps: inputs.timestamps,
    ndlCurve: analysis?.ndlCurve ?? const [],
    decoStopCurve: analysis?.decoStopCurve ?? const [],
  );
  if (end != null) return inputs.timestamps[end];
  var deepest = 0;
  for (var i = 1; i < inputs.depths.length; i++) {
    if (inputs.depths[i] > inputs.depths[deepest]) deepest = i;
  }
  return inputs.timestamps[deepest];
});
