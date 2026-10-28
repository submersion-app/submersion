import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/logged_dive_chain.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';

/// What a series following the logged dive [diveId] starts from (issue
/// #3565): the dive and the dives before it back to the first 48-hour gap,
/// each dive's OTU, and the followed dive's end tissues, CNS and tanks, from
/// the same analysis the dive details page runs. Null when the dive is gone.
final seriesFollowProvider = FutureProvider.family<SeriesFollow?, String>((
  ref,
  diveId,
) async {
  final dives = await ref.watch(divesProvider.future);
  final chain = loggedDiveChain(dives, diveId);
  if (chain.isEmpty) return null;
  // The list's dives carry no tanks.
  final followed = await ref.watch(diveProvider(diveId).future) ?? chain.last;

  final logged = <SeriesLoggedDive>[];
  final analyses = [
    for (final dive in chain)
      await ref.watch(profileAnalysisProvider(dive.id).future),
  ];
  for (var i = 0; i < chain.length; i++) {
    final dive = chain[i];
    logged.add(
      SeriesLoggedDive(
        id: dive.id,
        diveNumber: dive.diveNumber,
        name: dive.name,
        start: diveStart(dive),
        end: diveEnd(dive),
        otu: analyses[i]?.o2Exposure.otu ?? 0,
      ),
    );
  }

  final analysis = analyses.last;
  final statuses = analysis?.decoStatuses;
  return SeriesFollow(
    loggedDives: logged,
    endTissues: statuses == null || statuses.isEmpty
        ? null
        : statuses.last.compartments,
    endCns: analysis?.o2Exposure.cnsEnd ?? 0,
    endTanks: followed.tanks,
  );
});

/// Makes the series follow the logged dive [diveId], starting the first dive
/// after the time since it ended when that was recent, else after an hour.
/// Returns the follow, or null when the dive could not be read. [now] is in
/// the dive log's wall-clock-as-UTC frame, like the dives' own times.
Future<SeriesFollow?> followLoggedDive(
  WidgetRef ref,
  String diveId, {
  DateTime? now,
}) async {
  final follow = await ref.read(seriesFollowProvider(diveId).future);
  if (follow == null) return null;
  ref
      .read(planSeriesNotifierProvider.notifier)
      .followDive(
        follow,
        surfaceInterval: followSurfaceInterval(
          follow.followed.end,
          now: now ?? NoFlyService.wallClockNowUtc(),
        ),
      );
  return follow;
}

/// The most recent logged dive, when it ended less than 48 hours ago: the
/// one the planner offers to follow with a single tap. Null otherwise.
final followSuggestionProvider = FutureProvider<Dive?>((ref) async {
  final dives = await ref.watch(divesProvider.future);
  Dive? latest;
  for (final dive in dives) {
    if (dive.isPlanned) continue;
    if (latest == null || diveEnd(dive).isAfter(diveEnd(latest))) {
      latest = dive;
    }
  }
  if (latest == null) return null;
  // Dive times are wall clock stored as UTC; compare in the same frame.
  final since = NoFlyService.wallClockNowUtc().difference(diveEnd(latest));
  if (since.isNegative || since >= followLookback) return null;
  return latest;
});

/// Logged dives whose Follow prompt the diver dismissed this session.
final dismissedFollowSuggestionsProvider = StateProvider<Set<String>>(
  (ref) => const {},
);

/// The logged dive picked in the series bar, shown read-only in place of the
/// planner; null while a planned dive is shown.
final viewedLoggedDiveIdProvider = StateProvider<String?>((ref) => null);

/// The logged dive to show in place of the planner: the picked one, while
/// the series still follows it.
final viewedLoggedDiveProvider = Provider<SeriesLoggedDive?>((ref) {
  final id = ref.watch(viewedLoggedDiveIdProvider);
  if (id == null) return null;
  final follow = ref.watch(planSeriesNotifierProvider.select((s) => s.follow));
  for (final dive in follow?.loggedDives ?? const <SeriesLoggedDive>[]) {
    if (dive.id == id) return dive;
  }
  return null;
});
