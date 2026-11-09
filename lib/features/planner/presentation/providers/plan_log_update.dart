import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart'
    show PlanSummaryData;
import 'package:submersion/features/planner/data/services/planned_dives_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart'
    show SeriesDiveResult;
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';

/// What "Create / Update planned dives" did (issue #3565).
class PlannedDivesUpdate {
  /// False when a dive of the plan cannot be logged, so nothing was written.
  final bool valid;

  /// In a series, which dive stopped it: its name, else its letter.
  final String? blockedBy;

  /// Whether what stopped it is a dive with no segments, rather than one
  /// with a critical warning.
  final bool blockedEmpty;

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
    this.blockedEmpty = false,
    this.needsLinkMove = false,
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
    this.selectedDiveId,
    this.orphans = const [],
  });
}

/// The planned-dives writer over [container]'s repositories.
PlannedDivesWriter plannedDivesWriterOf(ProviderContainer container) =>
    PlannedDivesWriter(
      dives: container.read(diveRepositoryProvider),
      plans: container.read(divePlanRepositoryProvider),
      siteOf: (id) => container.read(siteProvider(id).future),
      shares: container.read(itemSharesRepositoryProvider),
    );

/// Creates or updates the planned entries in the log for every dive of the
/// plan in the planner, saves the plan, then links each new entry to its
/// dive, through [PlannedDivesWriter]. A dive already dived is left alone,
/// link and all: the log owns it now. An entry keeps its id, so its link
/// holds, and no link moves off a dive.
///
/// Saving never writes a link (see `DivePlanSeriesRepository.saveSeries`), so
/// the new links are made after the save and the planner adopts them.
/// Existing links are read from the plan rows, which the link actions keep
/// current; the series in memory can hold a stale one for a dive linked
/// while another was in the editor.
///
/// A single plan linked to a dived dive is the one exception, as Convert to
/// Dive was (#4058): its new entry takes the link off the dived dive, so this
/// returns [PlannedDivesUpdate.needsLinkMove] without writing until called
/// again with [moveDivedLink] once the diver agrees.
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
  final writer = plannedDivesWriterOf(container);

  // Read before the plan is read for writing: the diver can still edit
  // while these lookups run, and what is written must be the plan as it is
  // after them. Entries are matched to dives by plan id, never by position,
  // so a dive added or removed meanwhile cannot take another's entry.
  final diverId = container.read(currentDiverIdProvider);
  final lookups = await writer.lookUp(
    container.read(planSeriesNotifierProvider),
    diverId: diverId,
  );

  final series = container.read(planSeriesNotifierProvider);
  final plan = writer.decide(
    series,
    container.read(planSeriesResultsProvider),
    lookups,
    moveDivedLink: moveDivedLink,
  );
  if (plan.needsLinkMove) {
    return const PlannedDivesUpdate(needsLinkMove: true);
  }
  if (plan.blockedIndex case final i?) {
    return PlannedDivesUpdate(
      valid: false,
      blockedEmpty: plan.blockedEmpty,
      blockedBy: series.isSeries
          ? series.dives[i].name ?? seriesDiveLetter(i)
          : null,
    );
  }

  final written = await writer.write(
    plan,
    config: container.read(planEngineConfigProvider),
    // addDive reads the diver once on entry, with nothing awaited in
    // between, so a site checked for another diver is never attached.
    addDive: (dive) => log.addDive(
      container.read(currentDiverIdProvider) == diverId
          ? dive
          : dive.copyWith(clearSite: true),
    ),
    updateDive: log.updateDive,
  );

  final selected = series.dives[series.selectedIndex].state.id;
  final selectedDiveId =
      written.newEntries[selected] ??
      plan.steps
          .where((step) => step.planId == selected)
          .firstOrNull
          ?.entry
          ?.id;

  // A removed dive's row still links its entry until the series is saved,
  // so it is saved even when every dive left has been dived.
  if (written.created + written.updated > 0 ||
      notifier.removedLinkedDiveIds.isNotEmpty) {
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
  final adopted = await writer.link(written, onLinked: editor.adoptLink);
  if (notifier.mounted) notifier.adoptLinks(adopted);
  if (written.failure case final failure?) {
    Error.throwWithStackTrace(failure, written.failureStack!);
  }

  return PlannedDivesUpdate(
    created: written.created,
    updated: written.updated,
    skipped: written.skipped,
    selectedDiveId: selectedDiveId,
    orphans: await writer.orphans(notifier.removedLinkedDiveIds),
  );
}

/// Whether "Update planned dives" must ask for the first dive's start: a
/// series where some dive still to write has none to lay it out on. A dived
/// dive starts when it did, and the dives after it carry from that, so a
/// series begun by one needs none.
bool seriesNeedsFirstStart(PlanSeries series, List<SeriesDiveResult> results) =>
    series.isSeries &&
    results.any((r) => r.actual == null && r.state.startDateTime == null);
