import 'dart:async';

import 'package:flutter/foundation.dart' show compute;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';

typedef ScenarioRunner = Future<ScenarioOutcome> Function(ScenarioRequest);

/// Runs the engine on a background isolate. Tests override it with a
/// synchronous runner so no isolate is spawned under the test harness.
final scenarioEngineRunnerProvider = Provider<ScenarioRunner>(
  (_) =>
      (request) => compute(runScenarioEngine, request),
);

/// Edits within this window collapse into one engine run.
const Duration kLabRecomputeDebounce = Duration(milliseconds: 150);

/// The outcome for the current draft: null until the draft is seeded or
/// when the dive is ineligible. While a recompute is pending Riverpod keeps
/// the previous value on the loading state (read `valueOrNull`).
final scenarioOutcomeProvider = FutureProvider.autoDispose
    .family<ScenarioOutcome?, String>((ref, diveId) async {
      final draft = ref.watch(labDraftProvider(diveId));
      if (!draft.isSeeded) return null;
      final inputs = await ref.watch(labRequestInputsProvider(diveId).future);
      if (inputs == null) return null;
      var superseded = false;
      ref.onDispose(() => superseded = true);
      await Future<void>.delayed(kLabRecomputeDebounce);
      if (superseded) {
        // A newer draft already rebuilt this provider; never resolve so the
        // stale result cannot overwrite the fresh one.
        return Completer<ScenarioOutcome?>().future;
      }
      final run = ref.read(scenarioEngineRunnerProvider);
      return run(inputs.toRequest(draft.toScenario(diveId)));
    });
