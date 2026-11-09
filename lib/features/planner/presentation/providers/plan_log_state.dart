import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/planner/data/services/planned_dives_writer.dart'
    show plannedEntryName;
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/planner/presentation/providers/planned_log_entry.dart';

/// Where the plan's dives stand in the log (issue #3565, phase 2b): what the
/// "Create / Update planned dives" menu item says, and whether it has
/// anything to do.
class PlannedDivesLogState {
  /// Some dive of the plan has an entry in the log still only planned, so
  /// the item offers to update them rather than create them.
  final bool entriesExist;

  /// Running the item would change the log: a dive has no entry yet, or an
  /// entry differs from what its dive would write now, whether the plan
  /// changed (saved or not) or the entry was edited in the log.
  final bool outOfDate;

  const PlannedDivesLogState({
    required this.entriesExist,
    required this.outOfDate,
  });

  /// Before the first read settles: offered, and worded by the links the
  /// series holds in memory, which an update sets the moment it links its
  /// entries.
  factory PlannedDivesLogState.unsettled({required bool linked}) =>
      PlannedDivesLogState(entriesExist: linked, outOfDate: true);
}

/// What the log holds for the plan's dives, read once per change of what
/// decides it: the dives' plan ids, links and sites, the removed dives'
/// entries and the diver. An edit to a dive's profile reads nothing again.
class _LoggedEntries {
  /// Each dive's entry, by plan id (see [linkedEntries]).
  final Map<String, Dive?> entries;

  /// The stored profile of each entry still only planned, by dive id.
  final Map<String, List<DiveProfilePoint>> profiles;

  /// Each site as it may go on an entry, by (site id, the entry's diver).
  final Map<(String, String?), DiveSite?> sites;

  /// A removed dive's entry is still only planned and owed the offer.
  final bool removedPending;

  const _LoggedEntries({
    required this.entries,
    required this.profiles,
    required this.sites,
    required this.removedPending,
  });

  const _LoggedEntries.empty()
    : entries = const {},
      profiles = const {},
      sites = const {},
      removedPending = false;
}

final _loggedEntriesProvider = FutureProvider<_LoggedEntries>((ref) async {
  final plans = ref.watch(divePlanRepositoryProvider);
  final dives = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(plans.watchPlanSummaryChanges());
  ref.invalidateSelfWhen(dives.watchDivesChanges());
  // Joined into a string so the selection compares by value: an edit to a
  // dive's profile, gas or name leaves it alone.
  ref.watch(
    planSeriesNotifierProvider.select(
      (s) => [
        s.id,
        for (final dive in s.dives)
          '${dive.state.id}|${dive.state.linkedDiveId}|${dive.state.siteId}',
      ].join(','),
    ),
  );
  final removedIds = ref.watch(removedLinkedDiveIdsProvider);
  // Another diver sees other sites.
  ref.watch(currentDiverIdProvider);
  final shares = ref.read(itemSharesRepositoryProvider);
  final seriesRepository = ref.read(divePlanSeriesRepositoryProvider);
  final series = ref.read(planSeriesNotifierProvider);

  // A rebuild replaces this read; the reads still to come are skipped.
  var cancelled = false;
  ref.onDispose(() => cancelled = true);

  final entries = await linkedEntries(series, plans, dives);
  if (cancelled) return const _LoggedEntries.empty();

  final planned = [
    for (final entry in entries.values)
      if (entry != null && entry.isPlanned) entry,
  ];
  final profileList = await Future.wait([
    for (final entry in planned) dives.getDiveProfile(entry.id),
  ]);
  if (cancelled) return const _LoggedEntries.empty();

  // Checked for the diver the entry belongs to, as an update does.
  final sites = <(String, String?), DiveSite?>{};
  for (final dive in series.dives) {
    final siteId = dive.state.siteId;
    final entry = entries[dive.state.id];
    if (siteId == null || entry == null) continue;
    final key = (siteId, entry.diverId);
    if (sites.containsKey(key)) continue;
    sites[key] = await visiblePlanSite(
      await ref.read(siteProvider(siteId).future),
      entry.diverId,
      shares,
    );
    if (cancelled) return const _LoggedEntries.empty();
  }

  // A dive removed from the series whose entry is still planned in the log:
  // running the item offers to delete it. Until the series is saved, the
  // removed dive's own row still links it; a link from any other plan keeps
  // the entry, as the offer itself does.
  var removedPending = false;
  final planIds = {for (final dive in series.dives) dive.state.id};
  for (final id in removedIds) {
    final removed = await dives.getDiveById(id);
    if (removed == null || !removed.isPlanned) continue;
    final linker = await plans.getPlanByLinkedDiveId(id);
    if (linker != null &&
        (planIds.contains(linker.id) ||
            series.id == null ||
            await seriesRepository.seriesIdForPlan(linker.id) != series.id)) {
      continue;
    }
    removedPending = true;
    break;
  }

  return _LoggedEntries(
    entries: entries,
    profiles: {
      for (final (i, entry) in planned.indexed) entry.id: profileList[i],
    },
    sites: sites,
    removedPending: removedPending,
  );
});

/// The plan's dives against their entries in the log. Watched by the
/// planner page. The log is read again only when a link, site, removed dive
/// or the plan and dive tables change; an edit to the plan only compares
/// again, against what was read.
final plannedDivesLogStateProvider = FutureProvider<PlannedDivesLogState>((
  ref,
) async {
  final logged = await ref.watch(_loggedEntriesProvider.future);
  final series = ref.watch(planSeriesNotifierProvider);
  final results = ref.watch(planSeriesResultsProvider);
  final config = ref.watch(planEngineConfigProvider);

  var entriesExist = logged.removedPending;
  var outOfDate = logged.removedPending;
  for (var i = 0; i < series.dives.length && i < results.length; i++) {
    final entry = logged.entries[series.dives[i].state.id];
    if (entry == null) {
      outOfDate = true;
      continue;
    }
    if (!entry.isPlanned) {
      // A dived dive of a series is the log's now and is left alone. A
      // single plan linked to one still offers a new entry, which takes the
      // link once the diver agrees (#4058).
      if (!series.isSeries) outOfDate = true;
      continue;
    }
    entriesExist = true;
    if (outOfDate) continue;

    final result = results[i];
    final siteId = result.state.siteId;
    final site = siteId == null ? null : logged.sites[(siteId, entry.diverId)];
    final planned = PlannedLogEntry.of(
      result,
      name: plannedEntryName(series, i, result),
      config: config,
    );
    final profile = logged.profiles[entry.id] ?? const <DiveProfilePoint>[];
    if (!planned.matches(entry, profile, result.state, site)) {
      outOfDate = true;
    }
  }
  return PlannedDivesLogState(entriesExist: entriesExist, outOfDate: outOfDate);
});
