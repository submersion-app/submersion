import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart'
    show PlanSummaryData;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart'
    show SeriesDiveResult;
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';

const _uuid = Uuid();

/// What "Create / Update planned dives" did (issue #3565).
class PlannedDivesUpdate {
  /// False when a dive of the plan cannot be logged, so nothing was written.
  final bool valid;

  /// In a series, which dive stopped it: its name, else its letter.
  final String? blockedBy;
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
/// A series' entries take each dive's own name, or none, so a dived one goes
/// by its number. A single plan's only name is its own.
///
/// Takes the container rather than a `WidgetRef`: the writes outlive a page
/// the diver leaves during them.
Future<PlannedDivesUpdate> updatePlannedDives(
  ProviderContainer container,
) async {
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
      sites[id] = await _visibleSite(container, id, diverId);
    }
  }
  final linked = <int, Dive?>{};
  for (final (i, dive)
      in container.read(planSeriesNotifierProvider).dives.indexed) {
    final row = await plans.getPlan(dive.state.id);
    final id = row == null ? dive.state.linkedDiveId : row.linkedDiveId;
    linked[i] = id == null ? null : await repository.getDiveById(id);
  }

  final series = container.read(planSeriesNotifierProvider);
  final results = container.read(planSeriesResultsProvider);
  bool dived(int i) => linked[i] != null && !linked[i]!.isPlanned;
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
    final entry = _PlannedEntry.of(
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
    } else {
      await log.updateDive(entry.update(existing, result.state, site));
      await repository.saveEditedProfileWithKind(
        diveId: existing.id,
        editedPoints: entry.profile,
        editKind: 'plan_update',
      );
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

/// What a dive's entry in the log is made of, worked out from its result.
class _PlannedEntry {
  final String? name;
  final PlanOutcome outcome;
  final List<DiveProfilePoint> profile;
  final double avgDepth;

  const _PlannedEntry({
    required this.name,
    required this.outcome,
    required this.profile,
    required this.avgDepth,
  });

  /// The state's segments stop at the bottom; the engine computes the
  /// ascent. The entry takes the full computed profile so the log shows the
  /// deco schedule the plan produced.
  factory _PlannedEntry.of(
    SeriesDiveResult result, {
    required String? name,
    required PlanEngineConfig config,
  }) {
    final canvas = buildCanvasSeries(
      plan: divePlanFromState(result.state),
      outcome: result.outcome,
      config: config,
    );
    return _PlannedEntry(
      name: name,
      outcome: result.outcome,
      profile: [
        for (final point in canvas.profile)
          DiveProfilePoint(
            timestamp: point.timeSeconds.round(),
            depth: point.depth,
          ),
      ],
      avgDepth: PlanChartGeometry.meanDepthMeters(canvas.profile),
    );
  }

  /// A planned, unnumbered entry until the diver's download fills it or they
  /// mark it as logged (issue #2002).
  Dive newDive(DivePlanState state, DiveSite? site) => Dive(
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

  /// [existing] rewritten to the plan, under its own id.
  Dive update(Dive existing, DivePlanState state, DiveSite? site) =>
      existing.copyWith(
        name: name,
        clearName: name == null,
        dateTime: _start(state),
        runtime: Duration(seconds: outcome.runtimeSeconds),
        maxDepth: outcome.maxDepth,
        avgDepth: avgDepth,
        site: site,
        clearSite: site == null,
        notes: state.notes,
        altitude: state.altitude,
        waterType: state.waterType,
        gradientFactorLow: state.gfLow,
        gradientFactorHigh: state.gfHigh,
        tanks: _tanksFor(existing, state),
      );
}

/// When [state]'s dive goes in the log. Dive times are clock digits stamped
/// UTC; so is the plan's start.
DateTime _start(DivePlanState state) =>
    state.startDateTime ?? asWallClockUtc(clock.now());

/// [state]'s tanks under the ids of [existing]'s, by position: an update
/// must name each tank, and matching ids keeps those rows rather than
/// replacing them.
List<DiveTank> _tanksFor(Dive existing, DivePlanState state) => [
  for (final (index, tank) in state.tanks.indexed)
    tank.copyWith(
      id: index < existing.tanks.length ? existing.tanks[index].id : _uuid.v4(),
    ),
];

/// The site [id] when it may go on a dive of [diverId]. Saved plans are not
/// diver-scoped, so the plan may name a site private to another diver. A
/// shared site or one the diver owns qualifies, the rule the site list
/// applies (a site shared with this diver by name, or in a shared site
/// library, counts too, issue #2151), except that with no diver the dive is
/// unowned, where only an unowned site does. A site deleted since the plan
/// was saved resolves to null and is left off.
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
