import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
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

/// The plan's dives against their entries in the log. Watched by the
/// planner page, so it is read again whenever the plan changes, and
/// whenever the plan or dive tables do: a link made, an entry edited,
/// filled by a download or deleted.
final plannedDivesLogStateProvider = FutureProvider<PlannedDivesLogState>((
  ref,
) async {
  final plans = ref.watch(divePlanRepositoryProvider);
  final dives = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(plans.watchPlanSummaryChanges());
  final series = ref.watch(planSeriesNotifierProvider);
  final results = ref.watch(planSeriesResultsProvider);
  final config = ref.watch(planEngineConfigProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final shares = ref.read(itemSharesRepositoryProvider);
  final seriesRepository = ref.read(divePlanSeriesRepositoryProvider);

  final linked = await linkedEntries(series, plans, dives);
  var entriesExist = false;
  // A dive removed from the series whose entry is still planned in the log:
  // running the item offers to delete it. Until the series is saved, the
  // removed dive's own row still links it; a link from any other plan keeps
  // the entry, as the offer itself does.
  var outOfDate = false;
  final planIds = {for (final dive in series.dives) dive.state.id};
  for (final id
      in ref.read(planSeriesNotifierProvider.notifier).removedLinkedDiveIds) {
    final removed = await dives.getDiveById(id);
    if (removed == null || !removed.isPlanned) continue;
    final linker = await plans.getPlanByLinkedDiveId(id);
    if (linker != null &&
        (planIds.contains(linker.id) ||
            series.id == null ||
            await seriesRepository.seriesIdForPlan(linker.id) != series.id)) {
      continue;
    }
    entriesExist = true;
    outOfDate = true;
    break;
  }
  for (var i = 0; i < series.dives.length && i < results.length; i++) {
    final entry = linked[i];
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
    final site = siteId == null
        ? null
        : await visiblePlanSite(
            await ref.read(siteProvider(siteId).future),
            diverId,
            shares,
          );
    final planned = PlannedLogEntry.of(
      result,
      name: series.isSeries ? series.dives[i].name : result.state.name,
      config: config,
    );
    final profile = await dives.getDiveProfile(entry.id);
    if (!planned.matches(entry, profile, result.state, site)) {
      outOfDate = true;
    }
  }
  return PlannedDivesLogState(entriesExist: entriesExist, outOfDate: outOfDate);
});
