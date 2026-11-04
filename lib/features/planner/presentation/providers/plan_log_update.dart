import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart'
    show PlanSummaryData;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/plan_gas_switches.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart'
    show SeriesDiveResult;
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/planner/presentation/providers/planned_log_entry.dart';

/// What "Create / Update planned dives" did (issue #3565).
class PlannedDivesUpdate {
  /// False when a dive of the plan cannot be logged, so nothing was written.
  final bool valid;

  /// In a series, which dive stopped it: its name, else its letter.
  final String? blockedBy;

  /// A single plan linked to a dived dive: a new entry would take its link,
  /// so nothing was written until the diver agrees to move it.
  final bool needsLinkMove;
  final int created;
  final int updated;

  /// Dives left alone because they have been dived: the log owns them now.
  final int skipped;

  /// The log entry of the dive on screen, if it has one now.
  final String? selectedDiveId;

  /// Planned entries of dives since removed from the series, which no plan
  /// links any more: offered for deletion.
  final List<Dive> orphans;

  const PlannedDivesUpdate({
    this.valid = true,
    this.blockedBy,
    this.needsLinkMove = false,
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
    this.selectedDiveId,
    this.orphans = const [],
  });
}

/// Creates or updates the planned entries in the log for every dive of the
/// plan, saves the plan, then links each new entry to its dive. A dive
/// already dived is left alone, link and all: the log owns it now. An entry
/// keeps its id, so its link holds, and no link moves off a dive.
///
/// Saving never writes a link (see `DivePlanSeriesRepository.saveSeries`), so
/// the new links go through [DivePlanRepository.linkPlanToDive], as the link
/// actions do, and the planner adopts them. Existing links are read from the
/// plan rows, which the link actions keep current; the series in memory can
/// hold a stale one for a dive linked while another was in the editor.
///
/// A single plan linked to a dived dive is the one exception, as Convert to
/// Dive was (#4058): its new entry takes the link off the dived dive, so this
/// returns [PlannedDivesUpdate.needsLinkMove] without writing until called
/// again with [moveDivedLink] once the diver agrees.
///
/// A series' entries take each dive's own name, or none, so a dived one goes
/// by its number. A single plan's only name is its own.
///
/// Takes the container rather than a `WidgetRef`: the writes outlive a page
/// the diver leaves during them.
Future<PlannedDivesUpdate> updatePlannedDives(
  ProviderContainer container, {
  bool moveDivedLink = false,
}) async {
  final notifier = container.read(planSeriesNotifierProvider.notifier);
  final editor = container.read(divePlanNotifierProvider.notifier);
  final log = container.read(paginatedDiveListProvider.notifier);
  final repository = container.read(diveRepositoryProvider);
  final plans = container.read(divePlanRepositoryProvider);

  // Resolved before the plan is read for writing: the diver can still edit
  // while these lookups run, and what is written must be the plan as it is
  // after them.
  final diverId = container.read(currentDiverIdProvider);
  final sites = <String, DiveSite?>{};
  for (final dive in container.read(planSeriesNotifierProvider).dives) {
    final id = dive.state.siteId;
    if (id != null && !sites.containsKey(id)) {
      sites[id] = await visiblePlanSite(
        await container.read(siteProvider(id).future),
        diverId,
        container.read(itemSharesRepositoryProvider),
      );
    }
  }
  final linked = await linkedEntries(
    container.read(planSeriesNotifierProvider),
    plans,
    repository,
  );

  final series = container.read(planSeriesNotifierProvider);
  final results = container.read(planSeriesResultsProvider);
  bool dived(int i) => linked[i] != null && !linked[i]!.isPlanned;
  if (!series.isSeries && dived(0)) {
    if (!moveDivedLink) return const PlannedDivesUpdate(needsLinkMove: true);
    linked[0] = null;
  }
  for (final (i, result) in results.indexed) {
    if (dived(i)) continue;
    if (result.state.segments.isEmpty || !result.outcome.isDiveable) {
      return PlannedDivesUpdate(
        valid: false,
        blockedBy: series.isSeries
            ? series.dives[i].name ?? seriesDiveLetter(i)
            : null,
      );
    }
  }

  final config = container.read(planEngineConfigProvider);
  var created = 0;
  var updated = 0;
  var skipped = 0;
  final links = <int, String>{};
  for (var i = 0; i < series.dives.length; i++) {
    if (dived(i)) {
      skipped++;
      continue;
    }
    final dive = series.dives[i];
    final result = results[i];
    final entry = PlannedLogEntry.of(
      result,
      name: series.isSeries ? dive.name : result.state.name,
      config: config,
    );
    // addDive reads the diver once on entry, with nothing awaited in between,
    // so a site checked for another diver is never attached.
    final site = container.read(currentDiverIdProvider) == diverId
        ? sites[result.state.siteId]
        : null;
    // A link to an entry since deleted from the log is a dive with none.
    final existing = linked[i];
    if (existing == null) {
      final added = await log.addDive(entry.newDive(result.state, site));
      links[i] = added.id;
      created++;
      await _writeGasSwitches(repository, added.id, result);
    } else {
      await log.updateDive(entry.update(existing, result.state, site));
      await repository.saveEditedProfileWithKind(
        diveId: existing.id,
        editedPoints: entry.profile,
        editKind: 'plan_update',
      );
      await repository.deleteGasSwitchesForDive(existing.id);
      await _writeGasSwitches(repository, existing.id, result);
      updated++;
    }
  }

  final selected = series.selectedIndex;
  final selectedDiveId = links[selected] ?? linked[selected]?.id;

  if (created + updated > 0) {
    if (container.read(planSeriesNotifierProvider).savesAsSeries) {
      await saveCurrentSeries(container);
    } else {
      final outcome = container.read(planOutcomeProvider);
      await editor.save(
        summary: PlanSummaryData(
          maxDepth: outcome.maxDepth,
          runtimeSeconds: outcome.runtimeSeconds,
          ttsSeconds: outcome.ttsAtBottom,
        ),
      );
    }
  }

  // By plan id, which saving keeps: the diver may have edited meanwhile.
  final adopted = <String, String>{};
  for (final MapEntry(key: i, value: diveId) in links.entries) {
    final planId = series.dives[i].state.id;
    if (await plans.getPlan(planId) == null) continue;
    await plans.linkPlanToDive(planId, diveId);
    editor.adoptLink(planId, diveId);
    adopted[planId] = diveId;
  }
  if (notifier.mounted) notifier.adoptLinks(adopted);

  return PlannedDivesUpdate(
    created: created,
    updated: updated,
    skipped: skipped,
    selectedDiveId: selectedDiveId,
    orphans: await _orphans(container, notifier.removedLinkedDiveIds),
  );
}

/// The entries of [ids] still only planned that no plan links any more. Read
/// after the save, which deletes a removed dive's plan row; one still linked
/// belongs to some plan and is not offered.
Future<List<Dive>> _orphans(
  ProviderContainer container,
  Set<String> ids,
) async {
  final repository = container.read(diveRepositoryProvider);
  final plans = container.read(divePlanRepositoryProvider);
  final orphans = <Dive>[];
  for (final id in ids) {
    final dive = await repository.getDiveById(id);
    if (dive == null || !dive.isPlanned) continue;
    if (await plans.getPlanByLinkedDiveId(id) != null) continue;
    orphans.add(dive);
  }
  return orphans;
}

/// Writes the plan's gas switches onto its entry in the log, so the log's
/// analysis breathes what the plan breathes. They name no computer, so a
/// download clears them with the plan's profile. A loop's gas drifts with
/// depth on every line of its schedule, so only open circuit has switches to
/// write; a rebreather entry starts on its diluent (#4174).
Future<void> _writeGasSwitches(
  DiveRepository repository,
  String diveId,
  SeriesDiveResult result,
) async {
  if (result.state.mode != PlanMode.oc) return;
  final tanks = (await repository.getDiveById(diveId))?.tanks ?? const [];
  await repository.insertGasSwitches(
    plannedGasSwitches(
      result.outcome.schedule,
      planTanks: result.state.tanks,
      entryTanks: tanks,
      diveId: diveId,
      createdAt: DateTime.now(),
    ),
  );
}
