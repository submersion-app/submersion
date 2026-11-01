import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/domain/entities/compare_column.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/services/compare_columns.dart';
import 'package:submersion/features/dive_lab/presentation/providers/dive_scenario_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';

/// Whether a dive has a linked plan, for deciding if Compare shows at all.
final hasLinkedPlanProvider = Provider.family<bool, String>(
  (ref, diveId) => ref.watch(
    linkedPlanComparisonProvider(diveId).select((a) => a.value != null),
  ),
);

/// The linked plan's column; null with no plan, or a plan with no schedule.
final plannedColumnProvider = Provider.family<CompareColumn?, String>((
  ref,
  diveId,
) {
  final comparison = ref.watch(linkedPlanComparisonProvider(diveId)).value;
  if (comparison == null) return null;
  final plan = comparison.plan;
  return plannedColumn(
    outcome: comparison.outcome,
    // As the engine reads it: an altitude of zero or less is unset.
    surfacePressureBar: DiveEnvironment.forConditions(
      altitudeMeters: (plan.altitude ?? 0) > 0 ? plan.altitude : null,
      waterType: plan.waterType ?? WaterType.salt,
      salinityPpt: plan.salinityPpt,
    ).surfacePressureBar,
  );
});

/// The dive's own column. Null when the dive is gone.
final divedColumnProvider = FutureProvider.autoDispose
    .family<CompareColumn?, String>((ref, diveId) async {
      final dive = await ref.watch(diveProvider(diveId).future);
      if (dive == null) return null;
      // The samples the analysis replayed, so its curves line up with them:
      // on a dive with several computers the stored profile is another list.
      final series = await ref.watch(diveAnalysisSeriesProvider(diveId).future);
      final analysis = series == null
          ? null
          : await ref.watch(profileAnalysisProvider(diveId).future);
      return divedColumn(
        dive: dive,
        profile: series?.points ?? const [],
        analysis: analysis,
      );
    });

/// A saved what-if's outcome and its column; null when it cannot be run.
final whatIfLineProvider = FutureProvider.autoDispose
    .family<
      ({ScenarioOutcome outcome, CompareColumn column})?,
      SavedScenarioKey
    >((ref, key) async {
      final scenarios = await ref.watch(
        diveScenariosForDiveProvider(key.diveId).future,
      );
      DiveScenario? scenario;
      for (final s in scenarios) {
        if (s.id == key.scenarioId) scenario = s;
      }
      if (scenario == null) return null;
      final outcome = await ref.watch(savedScenarioOutcomeProvider(key).future);
      if (outcome == null) return null;
      return (
        outcome: outcome,
        column: whatIfColumn(scenario: scenario, outcome: outcome),
      );
    });

/// The lines a diver has turned on or off for a dive, by column id. Lines they
/// have not touched follow [compareLineOn]'s defaults.
final compareLinesProvider = StateProvider.autoDispose
    .family<Map<String, bool>, String>((ref, diveId) => const {});

/// Whether line [id] is showing. Planned and As dived start on, and so does
/// the newest saved what-if, so a dive with no plan still opens with two
/// columns; older what-ifs wait for their chips.
bool compareLineOn(
  Map<String, bool> overrides,
  String id, {
  String? newestWhatIfId,
}) {
  final choice = overrides[id];
  if (choice != null) return choice;
  return id == 'planned' || id == 'dived' || id == newestWhatIfId;
}
