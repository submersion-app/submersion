import 'package:clock/clock.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/logged_dive_chain.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';

/// What a series following the logged dive [diveId] starts from (issue
/// #3565): the dive and the dives before it back to the first 48-hour gap,
/// the OTU of those that can still count, and the followed dive's end
/// tissues, CNS and tanks, from the same analysis the dive details page runs.
/// Null when the dive is gone.
final seriesFollowProvider = FutureProvider.family<SeriesFollow?, String>((
  ref,
  diveId,
) async {
  final dives = await ref.watch(divesProvider.future);
  final chain = loggedDiveChain(dives, diveId);
  if (chain.isEmpty) return null;
  final followed = chain.last;
  final followedEnd = diveEnd(followed);

  final logged = <SeriesLoggedDive>[];
  ProfileAnalysis? analysis;
  for (final dive in chain) {
    final end = diveEnd(dive);
    // A dive that ended a day before the followed one can never count, and
    // a long chain would otherwise analyse every dive of the trip.
    analysis = followedEnd.difference(end) < otuCarryWindow
        ? await ref.watch(profileAnalysisProvider(dive.id).future)
        : null;
    logged.add(
      SeriesLoggedDive(
        id: dive.id,
        diveNumber: dive.diveNumber,
        name: dive.name,
        start: dive.effectiveEntryTime,
        end: end,
        endInstant: diveEndInstant(dive),
        otu: analysis?.o2Exposure.otu ?? 0,
      ),
    );
  }

  final statuses = analysis?.decoStatuses;
  return SeriesFollow(
    loggedDives: logged,
    endTissues: statuses == null || statuses.isEmpty
        ? null
        : statuses.last.compartments,
    endEnvironment: followed.environment,
    endCns: analysis?.o2Exposure.cnsEnd ?? 0,
    endTanks: followed.tanks,
  );
});

/// Makes the series follow the logged dive [diveId], starting the first dive
/// after the time since it ended when that was recent, else after an hour.
/// Returns the follow, or null when the dive could not be read.
///
/// The notifier is read first: the widget behind [ref] can be gone by the
/// time the analysis lands, and the follow still applies.
Future<SeriesFollow?> followLoggedDive(WidgetRef ref, String diveId) async {
  final notifier = ref.read(planSeriesNotifierProvider.notifier);
  final follow = await ref.container.awaitFuture(
    seriesFollowProvider(diveId).future,
  );
  if (follow == null) return null;
  notifier.followDive(
    follow,
    surfaceInterval: followSurfaceInterval(
      follow.followed.endInstant,
      now: clock.now(),
    ),
  );
  return follow;
}

/// The most recent logged dive, when it ended less than 48 hours ago: the
/// one the planner offers to follow with a single tap. Null otherwise.
///
/// Disposed with the planner, so each visit judges "recent" against the
/// clock then. A dive stamped in the future, a device clock gone wrong, is
/// passed over rather than hiding the one that really is the latest.
final followSuggestionProvider = FutureProvider.autoDispose<Dive?>((ref) async {
  final dives = await ref.watch(divesProvider.future);
  // Dive times are wall clock stored as UTC; compare in the same frame.
  final now = NoFlyService.wallClockNowUtc();
  Dive? latest;
  for (final dive in dives) {
    if (dive.isPlanned || diveEnd(dive).isAfter(now)) continue;
    if (latest == null || diveEnd(dive).isAfter(diveEnd(latest))) {
      latest = dive;
    }
  }
  if (latest == null) return null;
  return now.difference(diveEnd(latest)) < followLookback ? latest : null;
});

/// Logged dives whose Follow prompt the diver dismissed this session.
final dismissedFollowSuggestionsProvider = StateProvider<Set<String>>(
  (ref) => const {},
);

/// The logged dive picked in the series bar, shown read-only in place of the
/// planner; null while a planned dive is shown. Starts over whenever the
/// series follows a different dive or none, so a new follow opens on the
/// plan rather than on a dive picked in the last one.
final viewedLoggedDiveIdProvider = StateProvider<String?>((ref) {
  ref.watch(planSeriesNotifierProvider.select((s) => s.follow?.followed.id));
  return null;
});

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
