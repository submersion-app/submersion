import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';

final diveScenarioRepositoryProvider = Provider<DiveScenarioRepository>(
  (ref) => DiveScenarioRepository(),
);

/// Saved scenarios of one dive, newest first, live across saves, deletes and
/// sync.
final diveScenariosForDiveProvider =
    FutureProvider.family<List<DiveScenario>, String>((ref, diveId) async {
      final repository = ref.watch(diveScenarioRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchScenarioChanges());
      return repository.getScenariosForDive(diveId);
    });

typedef SavedScenarioKey = ({String diveId, String scenarioId});

/// The outcome of a saved scenario (teaser summaries); null when the dive is
/// ineligible or the scenario is gone.
final savedScenarioOutcomeProvider = FutureProvider.autoDispose
    .family<ScenarioOutcome?, SavedScenarioKey>((ref, key) async {
      final scenarios = await ref.watch(
        diveScenariosForDiveProvider(key.diveId).future,
      );
      DiveScenario? scenario;
      for (final s in scenarios) {
        if (s.id == key.scenarioId) scenario = s;
      }
      if (scenario == null) return null;
      final inputs = await ref.watch(
        labRequestInputsProvider(key.diveId).future,
      );
      if (inputs == null) return null;
      final run = ref.read(scenarioEngineRunnerProvider);
      return run(inputs.toRequest(scenario));
    });
