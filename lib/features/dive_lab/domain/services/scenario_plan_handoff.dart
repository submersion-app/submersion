import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/remaining_bottom_compiler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/dive_to_plan_converter.dart';
import 'package:uuid/uuid.dart';

/// What the planner could not take over from the scenario. Rendered through
/// l10n by the page before the planner opens.
enum ScenarioHandoffNote {
  /// The draft was in replay mode; a plan always re-plans the ascent.
  replayReplanned,

  /// `ascentPolicy.extraLastStopSeconds` has no planner equivalent: the
  /// planner's per-depth stop minimum is a floor, not an addition.
  extraLastStopNotCarried,

  /// A lost cylinder was breathed before the branch, so the authored segments
  /// reference it and it stays on the plan.
  lostTankKept,
}

class ScenarioPlanHandoffResult {
  const ScenarioPlanHandoffResult({required this.plan, required this.notes});

  final DivePlanState plan;
  final List<ScenarioHandoffNote> notes;
}

/// The rebuild sheet's default detail level, reused so a hand-off and a
/// rebuild of the same dive author the pre-branch profile identically.
const int kHandoffDetailLevels = 3;

/// Builds the unsaved plan "Open in planner" loads: the dive authored through
/// the branch sample by [DiveToPlanConverter], then the lab's compiled
/// remainder with its interventions already applied, computed from the
/// surface like any other plan. Exact after the branch, approximate before
/// it, exactly as the rebuild sheet is.
///
/// Open-circuit only: the converter cannot author loop segments, so a
/// rebreather [request] is refused rather than handed off as open circuit.
/// [outcome] must be computed in re-plan mode (it carries the compiled plan);
/// [scenario] is the draft as the diver had it, so a replay draft yields a
/// note rather than a silent mode change.
ScenarioPlanHandoffResult buildScenarioPlanHandoff({
  required ScenarioRequest request,
  required ScenarioOutcome outcome,
  required DiveScenario scenario,
  required Dive dive,
  required List<DiveProfilePoint> profile,
  required List<GasSwitch> gasSwitches,
  required DivePlanState defaults,
  required String planName,
  String Function()? idGenerator,
}) {
  if (request.diveMode != DiveMode.oc) {
    throw ArgumentError.value(
      request.diveMode,
      'request.diveMode',
      'the planner hand-off is open-circuit only',
    );
  }
  final compiled = outcome.compiledPlan;
  if (compiled == null) {
    throw ArgumentError.value(
      outcome.mode,
      'outcome.mode',
      'the hand-off needs an outcome computed in re-plan mode',
    );
  }
  final newId = idGenerator ?? const Uuid().v4;
  final branchTimestamp = request.timestamps[outcome.branch.index];

  final converted = const DiveToPlanConverter().convert(
    dive: dive,
    profile: profile,
    gasSwitches: gasSwitches,
    levels: kHandoffDetailLevels,
    planName: planName,
    defaults: defaults,
    throughTimestamp: branchTimestamp,
    idGenerator: newId,
  );

  final notes = <ScenarioHandoffNote>[];

  // The compiled plan carries pressures at the branch (it starts there). A
  // plan computed from the surface must start from the logged start pressure
  // or the pre-branch consumption is charged twice. A hypothetical tank has no
  // logged counterpart and keeps its own.
  final original = {for (final t in request.tanks) t.id: t};
  double? loggedStart(String tankId) {
    final start = original[tankId]?.startPressure;
    if (start != null) return start;
    // No logged start but a pressure series: its first sample is the closest
    // thing to a start pressure the dive has.
    final samples = request.tankPressures[tankId];
    if (samples == null || samples.isEmpty) return null;
    return samples
        .reduce((a, b) => a.timestamp <= b.timestamp ? a : b)
        .pressureBar;
  }

  var tanks = [
    for (final t in compiled.tanks)
      switch (loggedStart(t.id)) {
        final double p => t.copyWith(startPressure: p),
        _ => t,
      },
  ];
  // A dive logged without cylinders: the converter authored its segments
  // against the planner's default tanks, so those are the plan's tanks too,
  // or every segment would point at a tank the plan does not carry.
  if (tanks.isEmpty) tanks = converted.tanks;

  for (final i in scenario.interventions) {
    if (i is! LoseTankIntervention) continue;
    final breathedBefore = converted.segments.any((s) => s.tankId == i.tankId);
    final lost = original[i.tankId];
    if (breathedBefore && lost != null && !tanks.any((t) => t.id == lost.id)) {
      tanks = [...tanks, lost]..sort((a, b) => a.order.compareTo(b.order));
      notes.add(ScenarioHandoffNote.lostTankKept);
    }
  }

  // Plan segments and tanks are stored keyed by id alone, so nothing the lab
  // named deterministically may reach the plan: a hypothetical tank gets a
  // fresh id (the segments that breathe it follow), and so does every
  // remainder segment. The dive's own tanks keep their ids, as they do in the
  // rebuild flow.
  final logged = {...original.keys, ...converted.tanks.map((t) => t.id)};
  final tankIdMap = <String, String>{
    for (final t in tanks)
      if (!logged.contains(t.id)) t.id: newId(),
  };
  tanks = [
    for (final t in tanks)
      tankIdMap.containsKey(t.id) ? t.copyWith(id: tankIdMap[t.id]) : t,
  ];
  // A dive logged without cylinders: the lab's remainder names the
  // placeholder [kLabNoTankId]; it breathes the converter's last tank.
  final noTank = converted.segments.isNotEmpty
      ? tanks.firstWhere(
          (t) => t.id == converted.segments.last.tankId,
          orElse: () => tanks.first,
        )
      : (tanks.isEmpty ? null : tanks.first);

  final authored = converted.segments.length;
  final remainder = [
    for (final (i, s) in compiled.segments.indexed)
      if (s.tankId == kLabNoTankId && noTank != null)
        s.copyWith(
          id: newId(),
          order: authored + i,
          tankId: noTank.id,
          gasMix: noTank.gasMix,
        )
      else
        s.copyWith(
          id: newId(),
          order: authored + i,
          tankId: tankIdMap[s.tankId] ?? s.tankId,
        ),
  ];
  final segments = [...converted.segments, ...remainder];

  if (scenario.effectiveMode == ScenarioMode.replay) {
    notes.add(ScenarioHandoffNote.replayReplanned);
  }
  for (final i in scenario.interventions) {
    if (i is AscentPolicyIntervention && (i.extraLastStopSeconds ?? 0) > 0) {
      notes.add(ScenarioHandoffNote.extraLastStopNotCarried);
    }
  }

  final now = DateTime.now();
  final plan = stateFromDivePlan(compiled).copyWith(
    id: newId(),
    name: planName,
    segments: segments,
    tanks: tanks,
    initialTissueState: request.startCompartments,
    sourceDiveId: dive.id,
    altitude: converted.altitude,
    waterType: converted.waterType,
    salinityPpt: converted.salinityPpt,
    ppO2Bottom: request.settings.ppO2Working,
    ppO2Deco: request.settings.ppO2Deco,
    airBreaks: defaults.airBreaks,
    sacFactor: defaults.sacFactor,
    problemSolvingMinutes: defaults.problemSolvingMinutes,
    bestMixEndMeters: defaults.bestMixEndMeters,
    stopMinimums: const {},
    isDirty: false,
    createdAt: now,
    updatedAt: now,
  );
  return ScenarioPlanHandoffResult(plan: plan, notes: notes);
}
