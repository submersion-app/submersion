import 'package:clock/clock.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
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
///
/// The dive is found whichever diver it belongs to. Saved plans are not scoped
/// to a diver, so another profile can open a plan that follows this diver's
/// dive, and it must carry the same load rather than read as a fresh diver.
final seriesFollowProvider = FutureProvider.family<SeriesFollow?, String>((
  ref,
  diveId,
) async {
  var dives = await ref.watch(divesProvider.future);
  if (!dives.any((dive) => dive.id == diveId)) {
    final repository = ref.watch(diveRepositoryProvider);
    ref.invalidateSelfWhen(repository.watchDivesChanges());
    final dive = await repository.getDiveById(diveId);
    if (dive == null) return null;
    // A dive with no diver has no log of its own to chain through, and
    // reading every diver's dives would chain in someone else's.
    dives = dive.diverId == null
        ? [dive]
        : await repository.getAllDives(diverId: dive.diverId);
  }
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
        otu: analysis?.o2Exposure.otu,
        maxDepth: dive.maxDepth,
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
    endCns: analysis?.o2Exposure.cnsEnd,
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

/// The current diver's most recent logged dive, when it ended less than 48
/// hours ago: the one the planner offers to follow with a single tap. Null
/// otherwise.
///
/// Reads only the dives of the last days, never the whole log (issue #4250),
/// and only while the prompt can show: `PlanFollowPrompt` stops watching it
/// once the plan follows a dive or is a replan, and it is disposed then.
/// Disposed with the planner too, so each visit judges "recent" against the
/// clock then. A dive stamped in the future, a device clock gone wrong, is
/// passed over rather than hiding the one that really is the latest.
final followSuggestionProvider = FutureProvider.autoDispose<Dive?>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  // A dive with no runtime ends where its profile does, and a profile write
  // can leave the dive row alone, so this ticks on both.
  ref.invalidateSelfWhen(repository.watchMeasuredRuntimeChanges());
  // Dive times are wall clock stored as UTC; compare in the same frame.
  final now = NoFlyService.wallClockNowUtc();
  return repository.getLatestEndedDive(
    diverId: diverId,
    endedAfter: now.subtract(followLookback),
    notAfter: now,
  );
});

/// What the log says about the dives of the series that have been dived, by
/// plan id (issue #3565). A planned entry becomes a dive by Mark as logged,
/// the edit page's switch or a download, and an undone download reverses
/// that, so this watches the log. Nothing is read while no dive has an entry.
final seriesActualsProvider = FutureProvider<Map<String, SeriesFollow>>((
  ref,
) async {
  // Joined into a string so the selection compares by value: only a link
  // made, moved or dropped reads the log again, not every edit.
  final joined = ref.watch(
    planSeriesNotifierProvider.select(
      (s) => [
        for (final dive in s.dives)
          if (dive.state.linkedDiveId case final id?) '${dive.state.id}|$id',
      ].join(','),
    ),
  );
  if (joined.isEmpty) return const {};
  final links = [
    for (final link in joined.split(','))
      if (link.split('|') case [final planId, final diveId]) (planId, diveId),
  ];
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  return readSeriesActuals(
    links,
    repository,
    (diveId) => ref.watch(seriesFollowProvider(diveId).future),
  );
});

/// What the log says about [links], (plan id, dive id) pairs, by plan id:
/// for each entry no longer planned, the dive as a followed dive reads.
/// Shared by [seriesActualsProvider] and opening a saved plan, which reads
/// it before the plan shows so a dived dive never shows as a plan first.
Future<Map<String, SeriesFollow>> readSeriesActuals(
  Iterable<(String, String)> links,
  DiveRepository repository,
  Future<SeriesFollow?> Function(String diveId) followOf,
) async {
  // Each link is read on its own, so all of them at once.
  final read = await Future.wait([
    for (final (planId, diveId) in links)
      () async {
        final dive = await repository.getDiveById(diveId);
        if (dive == null || dive.isPlanned) return null;
        final follow = await followOf(diveId);
        return follow == null ? null : (planId, follow);
      }(),
  ]);
  return {
    for (final entry in read)
      if (entry case (final planId, final follow)) planId: follow,
  };
}

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
/// the series still follows it, else the selected dive of the series once it
/// has been dived (issue #3565).
final viewedLoggedDiveProvider = Provider<SeriesLoggedDive?>((ref) {
  final id = ref.watch(viewedLoggedDiveIdProvider);
  if (id == null) {
    // A dive of the series that has been dived shows what happened, unless
    // the diver asked for its plan.
    final actual = ref.watch(selectedDiveActualProvider);
    if (actual == null || ref.watch(showPlanOfDivedProvider)) return null;
    return actual.followed;
  }
  final follow = ref.watch(planSeriesNotifierProvider.select((s) => s.follow));
  for (final dive in follow?.loggedDives ?? const <SeriesLoggedDive>[]) {
    if (dive.id == id) return dive;
  }
  return null;
});
