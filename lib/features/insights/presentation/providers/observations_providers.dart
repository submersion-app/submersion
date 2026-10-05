import 'package:clock/clock.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/utils/local_day_changes.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/observation_inputs_loader.dart';
import 'package:submersion/features/insights/data/repositories/observation_dismissals_repository.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_engine.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final _log = LoggerService.forClass(ObservationInputsLoader);

final observationInputsLoaderProvider = Provider<ObservationInputsLoader>(
  (ref) =>
      ObservationInputsLoader(insights: ref.watch(insightsRepositoryProvider)),
);

final observationDismissalsRepositoryProvider =
    Provider<ObservationDismissalsRepository>(
      (ref) => ObservationDismissalsRepository(),
    );

/// The whole log of the current diver, never the Insights view filter
/// (spec section 3). Refreshes on any Insights table change and at local
/// midnight, since every window is measured back from "now".
final observationInputsProvider = FutureProvider<ObservationInputs>((
  ref,
) async {
  final loader = ref.watch(observationInputsLoaderProvider);
  final repository = ref.watch(insightsRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final diverFuture = ref.watch(currentDiverProvider.future);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  ref.invalidateSelfWhen(localDayChanges());
  final diver = await diverFuture;
  return loader.load(
    diverId: diverId,
    diver: diver,
    now: asWallClockUtc(clock.now()),
  );
});

/// Keys the current diver dismissed; empty with no diver. A Drift watch
/// stream, so it follows writes from this device and from sync.
final dismissedObservationKeysProvider = StreamProvider<Set<String>>((
  ref,
) async* {
  final diver = await ref.watch(currentDiverProvider.future);
  if (diver == null) {
    yield const <String>{};
    return;
  }
  yield* ref
      .watch(observationDismissalsRepositoryProvider)
      .watchDismissedKeys(diver.id);
});

/// Every observation for the current diver, ranked, without muted rules or
/// dismissed fingerprints.
final observationsProvider = FutureProvider<List<Observation>>((ref) async {
  final inputsFuture = ref.watch(observationInputsProvider.future);
  final dismissedFuture = ref.watch(dismissedObservationKeysProvider.future);
  final muted = ref.watch(
    settingsProvider.select((s) => s.insightsMutedObservationRules),
  );
  final inputs = await inputsFuture;
  final dismissed = await dismissedFuture;
  return runObservationRules(
    inputs,
    mutedRuleIds: muted,
    dismissedKeys: dismissed,
    onRuleError: (rule, error, stack) => _log.error(
      'Observation rule ${rule.dbValue} failed',
      error: error,
      stackTrace: stack,
    ),
  );
});

/// The landing strip's observations (spec section 4.4).
final observationStripProvider = Provider<AsyncValue<List<Observation>>>(
  (ref) => ref.watch(observationsProvider).whenData(selectStrip),
);
