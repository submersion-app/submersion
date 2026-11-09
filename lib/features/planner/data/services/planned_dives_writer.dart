import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_gas_switches.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart'
    show SeriesDiveResult;
import 'package:submersion/features/planner/presentation/providers/planned_log_entry.dart';

/// The name the log entry of the dive at [index] of [series], computed as
/// [result], takes: in a series each dive's own, or none, so a dived one
/// goes by its number; a single plan's only name is its own. Shared by the
/// writer and the planner's check of whether its entries are up to date.
String? plannedEntryName(
  PlanSeries series,
  int index,
  SeriesDiveResult result,
) => series.isSeries ? series.dives[index].name : result.state.name;

/// What "Create / Update planned dives" does with one dive of a plan
/// (issue #3565).
enum PlannedDiveAction {
  /// The dive has no entry in the log: a new planned entry is made.
  create,

  /// Its entry is still only planned: rewritten in place, same id.
  update,

  /// Its entry has been dived: the log owns it now, so it is left alone.
  skipDived,
}

/// What the log and the sites hold for a plan's dives, read before the plan
/// is decided on. The planner reads these while the diver can still edit,
/// and decides on the plan as it is after them, so everything here is keyed
/// by plan id and site id, never by position.
class PlannedDivesLookups {
  /// Each dive's entry in the log, by plan id; see [linkedEntries].
  final Map<String, Dive?> entries;

  /// Each site as it may go on an entry, by (site id, diver id).
  final Map<(String?, String?), DiveSite?> sites;

  /// Whom a new entry belongs to.
  final String? diverId;

  const PlannedDivesLookups({
    required this.entries,
    required this.sites,
    required this.diverId,
  });
}

/// One dive of a plan and what writing the plan does with it.
class PlannedDiveStep {
  final int index;
  final String planId;
  final PlannedDiveAction action;

  /// The entry an update rewrites, or the dived entry a skip leaves; null
  /// for a create.
  final Dive? entry;

  final SeriesDiveResult result;

  /// The entry's name: in a series each dive's own, or none; a single
  /// plan's only name is its own.
  final String? name;

  /// The plan's site as it may go on the entry, checked for whoever the
  /// entry belongs to; null when it has none or that diver cannot see it.
  final DiveSite? site;

  const PlannedDiveStep({
    required this.index,
    required this.planId,
    required this.action,
    required this.entry,
    required this.result,
    required this.name,
    required this.site,
  });
}

/// What writing a plan to the log would do, decided without writing.
class PlannedDivesPlan {
  final List<PlannedDiveStep> steps;

  /// A single plan linked to a dived dive: a new entry would take its link,
  /// so nothing may be written until the diver agrees to move it.
  final bool needsLinkMove;

  /// The dive that cannot be logged, so nothing may be written: an empty
  /// one, or one with a critical warning. Null when every dive can be.
  final int? blockedIndex;

  /// Whether what blocks it is a dive with no segments.
  final bool blockedEmpty;

  const PlannedDivesPlan({
    this.steps = const [],
    this.needsLinkMove = false,
    this.blockedIndex,
    this.blockedEmpty = false,
  });

  /// Whether the plan may be written.
  bool get writable => !needsLinkMove && blockedIndex == null;
}

/// What [PlannedDivesWriter.write] wrote.
class PlannedDivesWritten {
  final int created;
  final int updated;
  final int skipped;

  /// The new entries, by the plan id of their dive. Not linked yet.
  final Map<String, String> newEntries;

  /// What stopped the writes part way, rethrown by the caller once what was
  /// written is linked, so no entry is orphaned and made again by the next
  /// run. Null when every write went through.
  final Object? failure;
  final StackTrace? failureStack;

  const PlannedDivesWritten({
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
    this.newEntries = const {},
    this.failure,
    this.failureStack,
  });
}

/// Writes a plan's dives into the log as planned entries (issue #3565): the
/// work behind the planner's "Create / Update planned dives", without the
/// planner, so anything holding a plan and its results writes the same
/// entries.
///
/// In three steps, because the planner saves the plan between the second
/// and the third: [lookUp] and [decide], which write nothing; [write], which
/// makes and rewrites the entries; and [link], which links each new entry to
/// its dive once the plan rows exist. A dive already dived is left alone,
/// link and all, and an entry keeps its id, so its link holds.
class PlannedDivesWriter {
  PlannedDivesWriter({
    required DiveRepository dives,
    required DivePlanRepository plans,
    required Future<DiveSite?> Function(String siteId) siteOf,
    required ItemSharesRepository shares,
  }) : _dives = dives,
       _plans = plans,
       _siteOf = siteOf,
       _shares = shares;

  final DiveRepository _dives;
  final DivePlanRepository _plans;

  /// Reads a site by id: the planner's cached `siteProvider`, or the site
  /// repository where there is no planner.
  final Future<DiveSite?> Function(String siteId) _siteOf;
  final ItemSharesRepository _shares;

  /// Reads each dive's entry and each site as it may go on it, for
  /// [series] written for [diverId]. For a dive with an entry, the site is
  /// checked for the entry's own diver, which an update keeps; for one
  /// without, for [diverId], whom a new entry belongs to.
  Future<PlannedDivesLookups> lookUp(
    PlanSeries series, {
    required String? diverId,
  }) async {
    final entries = await linkedEntries(series, _plans, _dives);
    final sites = <(String?, String?), DiveSite?>{};
    Future<void> add(String siteId, String? owner) async {
      if (sites.containsKey((siteId, owner))) return;
      sites[(siteId, owner)] = await visiblePlanSite(
        await _siteOf(siteId),
        owner,
        _shares,
      );
    }

    for (final dive in series.dives) {
      final id = dive.state.siteId;
      if (id == null) continue;
      final entry = entries[dive.state.id];
      await add(id, entry == null ? diverId : entry.diverId);
      // A single plan whose dived link moves gets a new entry for [diverId].
      // Read for any dived dive: a dive removed while these lookups run can
      // leave a series a single plan by the time it is decided on.
      if (entry != null && !entry.isPlanned) await add(id, diverId);
    }
    return PlannedDivesLookups(
      entries: entries,
      sites: sites,
      diverId: diverId,
    );
  }

  /// What writing [series], computed as [results], does with each dive,
  /// from what [lookups] read. A single plan linked to a dived dive needs
  /// [moveDivedLink] before its new entry may take the link, as Convert to
  /// Dive did (#4058).
  PlannedDivesPlan decide(
    PlanSeries series,
    List<SeriesDiveResult> results,
    PlannedDivesLookups lookups, {
    bool moveDivedLink = false,
  }) {
    final entries = {
      for (final dive in series.dives)
        dive.state.id: lookups.entries[dive.state.id],
    };
    bool dived(int i) {
      final entry = entries[series.dives[i].state.id];
      return entry != null && !entry.isPlanned;
    }

    if (!series.isSeries && dived(0)) {
      if (!moveDivedLink) return const PlannedDivesPlan(needsLinkMove: true);
      entries[series.dives[0].state.id] = null;
    }
    for (final (i, result) in results.indexed) {
      if (dived(i)) continue;
      final empty = result.state.segments.isEmpty;
      if (empty || !result.outcome.isDiveable) {
        return PlannedDivesPlan(blockedIndex: i, blockedEmpty: empty);
      }
    }

    return PlannedDivesPlan(
      steps: [
        for (var i = 0; i < series.dives.length; i++)
          _step(
            series,
            i,
            results[i],
            entries[series.dives[i].state.id],
            lookups,
          ),
      ],
    );
  }

  /// What writing does with the dive at [index] of [series], computed as
  /// [result], whose entry in the log is [entry].
  PlannedDiveStep _step(
    PlanSeries series,
    int index,
    SeriesDiveResult result,
    Dive? entry,
    PlannedDivesLookups lookups,
  ) {
    final owner = entry == null ? lookups.diverId : entry.diverId;
    return PlannedDiveStep(
      index: index,
      planId: series.dives[index].state.id,
      action: entry == null
          ? PlannedDiveAction.create
          : entry.isPlanned
          ? PlannedDiveAction.update
          : PlannedDiveAction.skipDived,
      entry: entry,
      result: result,
      name: plannedEntryName(series, index, result),
      site: lookups.sites[(result.state.siteId, owner)],
    );
  }

  /// Makes and rewrites the entries [plan] lists, through [addDive] and
  /// [updateDive], which write a dive row as the caller's log does. A write
  /// that fails part way stops there and is returned, not thrown, so the
  /// caller can still link what was written.
  ///
  /// [plan] must be one [decide] let through ([PlannedDivesPlan.writable]);
  /// any other is an [ArgumentError], in release builds too.
  Future<PlannedDivesWritten> write(
    PlannedDivesPlan plan, {
    required PlanEngineConfig config,
    required Future<Dive> Function(Dive dive) addDive,
    required Future<void> Function(Dive dive) updateDive,
  }) async {
    if (!plan.writable) {
      throw ArgumentError.value(
        plan,
        'plan',
        'needs a plan decide() let through',
      );
    }
    var created = 0;
    var updated = 0;
    var skipped = 0;
    final links = <String, String>{};
    // Built only for a dive written: a dived one's entry is never used.
    PlannedLogEntry entryOf(PlannedDiveStep step) =>
        PlannedLogEntry.of(step.result, name: step.name, config: config);
    try {
      for (final step in plan.steps) {
        final result = step.result;
        switch (step.action) {
          case PlannedDiveAction.skipDived:
            skipped++;
          case PlannedDiveAction.create:
            final entry = entryOf(step);
            final added = await addDive(entry.newDive(result.state, step.site));
            links[step.planId] = added.id;
            created++;
            await _writeGasSwitches(added.id, result);
          case PlannedDiveAction.update:
            final entry = entryOf(step);
            final existing = step.entry!;
            await updateDive(entry.update(existing, result.state, step.site));
            await _dives.replacePlannedProfile(
              diveId: existing.id,
              points: entry.profile,
            );
            await _dives.deleteGasSwitchesForDive(existing.id);
            await _writeGasSwitches(existing.id, result);
            updated++;
        }
      }
    } catch (error, stack) {
      return PlannedDivesWritten(
        created: created,
        updated: updated,
        skipped: skipped,
        newEntries: links,
        failure: error,
        failureStack: stack,
      );
    }
    return PlannedDivesWritten(
      created: created,
      updated: updated,
      skipped: skipped,
      newEntries: links,
    );
  }

  /// Links each new entry of [written] to its dive's plan row, through
  /// [DivePlanRepository.linkPlanToDive] as the link actions do: saving a
  /// plan never writes a link. A plan whose row is gone is passed over.
  /// [onLinked] hears each link as it is made. Returns the links made, by
  /// plan id.
  Future<Map<String, String>> link(
    PlannedDivesWritten written, {
    void Function(String planId, String diveId)? onLinked,
  }) async {
    final linked = <String, String>{};
    for (final MapEntry(key: planId, value: diveId)
        in written.newEntries.entries) {
      if (await _plans.getPlan(planId) == null) continue;
      await _plans.linkPlanToDive(planId, diveId);
      onLinked?.call(planId, diveId);
      linked[planId] = diveId;
    }
    return linked;
  }

  /// The entries of [ids] still only planned that no plan links any more.
  /// Read after the plan is saved, which deletes a removed dive's plan row;
  /// one still linked belongs to some plan.
  Future<List<Dive>> orphans(Set<String> ids) async {
    final orphans = <Dive>[];
    for (final id in ids) {
      final dive = await _dives.getDiveById(id);
      if (dive == null || !dive.isPlanned) continue;
      if (await _plans.getPlanByLinkedDiveId(id) != null) continue;
      orphans.add(dive);
    }
    return orphans;
  }

  /// Writes the plan's gas switches onto its entry, so the log's analysis
  /// breathes what the plan breathes. They name no computer, so a download
  /// clears them with the plan's profile. A loop's gas drifts with depth on
  /// every line of its schedule, so only open circuit has switches to
  /// write; a rebreather entry starts on its diluent (#4174).
  Future<void> _writeGasSwitches(String diveId, SeriesDiveResult result) async {
    if (result.state.mode != PlanMode.oc) return;
    final tanks = (await _dives.getDiveById(diveId))?.tanks ?? const [];
    await _dives.insertGasSwitches(
      plannedGasSwitches(
        result.outcome.schedule,
        planTanks: result.state.tanks,
        entryTanks: tanks,
        diveId: diveId,
        createdAt: DateTime.now(),
      ),
    );
  }
}
