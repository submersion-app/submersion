import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart'
    show PlanSummaryData;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';

const _uuid = Uuid();

/// What updating the planned dives in the log did (issue #3565).
class PlannedDivesUpdate {
  /// False when a dive of the plan cannot be logged, so nothing was written.
  final bool valid;

  /// In a series, which dive stopped it: its name, else its letter.
  final String? blockedBy;
  final int created;
  final int updated;

  /// The log entry of the dive on screen, if it has one now.
  final String? selectedDiveId;

  /// Planned entries of dives since removed from the series, still in the log.
  final List<Dive> orphans;

  const PlannedDivesUpdate({
    this.valid = true,
    this.blockedBy,
    this.created = 0,
    this.updated = 0,
    this.selectedDiveId,
    this.orphans = const [],
  });
}

/// Creates or updates the planned entries in the log for every dive of the
/// plan, then saves the plan with its links. A dive already dived is left
/// alone: the log owns it now. An entry keeps its id, so its link holds.
///
/// A series' entries are named by each dive's own name, or left unnamed so a
/// completed dive goes by its number. A single plan's only name is its own.
Future<PlannedDivesUpdate> updatePlannedDives(
  ProviderContainer container,
) async {
  final notifier = container.read(planSeriesNotifierProvider.notifier);
  final editor = container.read(divePlanNotifierProvider.notifier);
  final log = container.read(paginatedDiveListProvider.notifier);
  final repository = container.read(diveRepositoryProvider);

  // Resolved before anything is read for writing: the diver can still edit
  // while these lookups run, and the plan below must be the plan as it is now.
  final diverId = container.read(currentDiverIdProvider);
  final sites = <String, DiveSite?>{};
  for (final dive in container.read(planSeriesNotifierProvider).dives) {
    final id = dive.state.siteId;
    if (id != null && !sites.containsKey(id)) {
      sites[id] = await _visibleSite(container, id, diverId);
    }
  }
  final sameDiver = container.read(currentDiverIdProvider) == diverId;

  final series = container.read(planSeriesNotifierProvider);
  final results = container.read(planSeriesResultsProvider);
  for (final (i, result) in results.indexed) {
    if (result.actual != null) continue;
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
  final links = <int, String>{};
  for (var i = 0; i < series.dives.length; i++) {
    final dive = series.dives[i];
    final result = results[i];
    final linkedId = dive.state.linkedDiveId;
    final linked = linkedId == null
        ? null
        : await repository.getDiveById(linkedId);
    if (linked != null && !linked.isPlanned) continue;

    final canvas = buildCanvasSeries(
      plan: divePlanFromState(result.state),
      outcome: result.outcome,
      config: config,
    );
    final profile = [
      for (final point in canvas.profile)
        DiveProfilePoint(
          timestamp: point.timeSeconds.round(),
          depth: point.depth,
        ),
    ];
    final name = series.isSeries ? dive.name : result.state.name;
    final site = sameDiver ? sites[result.state.siteId] : null;
    final avgDepth = PlanChartGeometry.meanDepthMeters(canvas.profile);

    if (linked == null) {
      final added = await log.addDive(
        _newPlannedDive(
          result.state,
          result.outcome,
          name: name,
          site: site,
          profile: profile,
          avgDepth: avgDepth,
        ),
      );
      links[i] = added.id;
      created++;
    } else {
      await log.updateDive(
        linked.copyWith(
          name: name,
          clearName: name == null,
          dateTime: _start(result.state),
          runtime: Duration(seconds: result.outcome.runtimeSeconds),
          maxDepth: result.outcome.maxDepth,
          avgDepth: avgDepth,
          site: site,
          clearSite: site == null,
          notes: result.state.notes,
          altitude: result.state.altitude,
          waterType: result.state.waterType,
          gradientFactorLow: result.state.gfLow,
          gradientFactorHigh: result.state.gfHigh,
          tanks: _tanksFor(linked, result.state),
        ),
      );
      await repository.saveEditedProfileWithKind(
        diveId: linked.id,
        editedPoints: profile,
        editKind: 'plan_update',
      );
      updated++;
    }
  }

  final selected = series.selectedIndex;
  final selectedDiveId = links[selected] ?? series.selected.state.linkedDiveId;
  if (links.isNotEmpty) notifier.setLinkedDives(links);

  final orphans = <Dive>[];
  for (final id in series.removedLinkedDiveIds) {
    final dive = await repository.getDiveById(id);
    if (dive != null && dive.isPlanned) orphans.add(dive);
  }

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
  return PlannedDivesUpdate(
    created: created,
    updated: updated,
    selectedDiveId: selectedDiveId,
    orphans: orphans,
  );
}

/// When [state]'s dive goes in the log. Dive times are clock digits stamped
/// UTC; so is the plan's start.
DateTime _start(DivePlanState state) =>
    state.startDateTime ?? asWallClockUtc(clock.now());

/// A planned, unnumbered entry until the diver's download fills it or they
/// mark it as logged (issue #2002).
Dive _newPlannedDive(
  DivePlanState state,
  PlanOutcome outcome, {
  required String? name,
  required DiveSite? site,
  required List<DiveProfilePoint> profile,
  required double avgDepth,
}) {
  return Dive(
    id: _uuid.v4(),
    name: name,
    dateTime: _start(state),
    runtime: Duration(seconds: outcome.runtimeSeconds),
    maxDepth: outcome.maxDepth,
    avgDepth: avgDepth,
    site: site,
    tanks: [for (final tank in state.tanks) tank.copyWith(id: '')],
    profile: profile,
    notes: state.notes,
    altitude: state.altitude,
    waterType: state.waterType,
    gradientFactorLow: state.gfLow,
    gradientFactorHigh: state.gfHigh,
    isPlanned: true,
  );
}

/// [state]'s tanks under the ids of [linked]'s, by position: an update must
/// name each tank, and matching ids keeps those rows rather than replacing them.
List<DiveTank> _tanksFor(Dive linked, DivePlanState state) => [
  for (final (index, tank) in state.tanks.indexed)
    tank.copyWith(
      id: index < linked.tanks.length ? linked.tanks[index].id : _uuid.v4(),
    ),
];

/// The site [id] when it may go on a dive of [diverId]: saved plans are not
/// diver-scoped, so the plan may name a site private to another diver. A shared
/// site or one the diver owns qualifies, the rule the site list applies, except
/// that with no diver the dive is unowned, where only an unowned site does. A
/// site deleted since the plan was saved resolves to null and is left off.
Future<DiveSite?> _visibleSite(
  ProviderContainer container,
  String id,
  String? diverId,
) async {
  final site = await container.read(siteProvider(id).future);
  if (site == null) return null;
  if (diverId == null) {
    return site.isShared || site.diverId == null ? site : null;
  }
  if (site.diverId == diverId || site.isShared) return site;
  final shared = await container
      .read(itemSharesRepositoryProvider)
      .isVisibleTo(SharedItemKind.site, site.id, diverId);
  return shared ? site : null;
}

/// The plan linked to the logged dive [diveId], which the log links back to;
/// null when none is, or the plan has since been deleted, which simply takes
/// the link away.
final planLinkedToDiveProvider = FutureProvider.family<String?, String>((
  ref,
  diveId,
) async {
  final plans = ref.watch(divePlanRepositoryProvider);
  ref.invalidateSelfWhen(plans.watchPlanChanges());
  return (await plans.getPlanByLinkedDiveId(diveId))?.id;
});
