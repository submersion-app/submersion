import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/services/draft_conditions_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/tides/data/services/dive_tide_recorder.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

/// Weather and tide for drafts (issue #637). Kept alive for the app's
/// lifetime, since it remembers which drafts it tried this session.
// no-tick: builds the DraftConditionsService SERVICE, not a query result.
final draftConditionsServiceProvider = Provider<DraftConditionsService>((ref) {
  final tides = ref.watch(tideRecordRepositoryProvider);
  return DraftConditionsService(
    dives: ref.watch(diveRepositoryProvider),
    drafts: ref.watch(diveDraftRepositoryProvider),
    weather: ref.watch(weatherServiceProvider),
    recordTide: (dive, at) async {
      final calculator = await ref.read(tideCalculatorProvider(at).future);
      if (calculator == null) return;
      await recordDiveTide(
        repository: tides,
        calculator: calculator,
        diveId: dive.id,
        entryWallClock: dive.entryTime ?? dive.dateTime,
        location: at,
        waterType: dive.waterType,
      );
    },
    hasTide: tides.hasTideRecord,
  );
});

final _log = LoggerService.forClass(DraftConditionsService);

/// Fills conditions for the current diver's drafts as they surface: re-run
/// on every dive change, and at launch, where it retries what failed last
/// time. Listened to for the app's lifetime; never fails.
final draftConditionsSyncProvider = FutureProvider<void>((ref) async {
  ref.invalidateSelfWhen(ref.watch(diveRepositoryProvider).watchDivesChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  try {
    await ref
        .read(draftConditionsServiceProvider)
        .fillPending(diverId: diverId);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to fill conditions for drafts',
      error: e,
      stackTrace: stackTrace,
    );
  }
});
