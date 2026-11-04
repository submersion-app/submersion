import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_profile_samples.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart'
    show SeriesDiveResult;
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

const _uuid = Uuid();

/// A depth difference below this is the same sample: the log stores
/// profile depths packed, so a round trip need not give back the exact
/// double that went in.
const _depthTolerance = 0.01;

/// What a dive's planned entry in the log is made of, worked out from its
/// result (issue #3565). "Create / Update planned dives" writes it, and the
/// planner compares it with the entry to know whether the log is behind.
class PlannedLogEntry {
  final String? name;
  final PlanOutcome outcome;
  final List<DiveProfilePoint> profile;
  final double avgDepth;

  const PlannedLogEntry({
    required this.name,
    required this.outcome,
    required this.profile,
    required this.avgDepth,
  });

  /// The state's segments stop at the bottom; the engine computes the
  /// ascent. The entry takes the full computed profile so the log shows the
  /// deco schedule the plan produced, sampled every 10 seconds like a dive
  /// computer's: the log analyses a dive only at its samples.
  factory PlannedLogEntry.of(
    SeriesDiveResult result, {
    required String? name,
    required PlanEngineConfig config,
  }) {
    final canvas = buildCanvasSeries(
      plan: divePlanFromState(result.state),
      outcome: result.outcome,
      config: config,
    );
    return PlannedLogEntry(
      name: name,
      outcome: result.outcome,
      profile: sampledPlanProfile([
        for (final point in canvas.profile)
          DiveProfilePoint(
            timestamp: point.timeSeconds.round(),
            depth: point.depth,
          ),
      ]),
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
    diveMode: _diveMode(state.mode),
    setpointLow: _onLoop(state) ? state.setpointLow : null,
    setpointHigh: _onLoop(state) ? state.setpointHigh : null,
    diluentGas: _diluent(state),
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
        diveMode: _diveMode(state.mode),
        setpointLow: _onLoop(state) ? state.setpointLow : null,
        setpointHigh: _onLoop(state) ? state.setpointHigh : null,
        clearSetpoints: !_onLoop(state),
        diluentGas: _diluent(state),
        clearDiluentGas: _diluent(state) == null,
        tanks: _tanksFor(existing, state),
      );

  /// Whether [existing], whose profile in the log is [storedProfile], is
  /// what an update would write for [state] at [site]: nothing for "Update
  /// planned dives" to do. Only what the plan sets is compared. Depth stats
  /// are left out, since the log works them out again from the profile it
  /// stores, and so are the gas switches, which follow from the profile and
  /// the tanks.
  bool matches(
    Dive existing,
    List<DiveProfilePoint> storedProfile,
    DivePlanState state,
    DiveSite? site,
  ) {
    if (state.startDateTime == null) return false;
    return existing.name == name &&
        existing.dateTime == _start(state) &&
        existing.runtime == Duration(seconds: outcome.runtimeSeconds) &&
        existing.site?.id == site?.id &&
        existing.notes == state.notes &&
        existing.altitude == state.altitude &&
        existing.waterType == state.waterType &&
        existing.gradientFactorLow == state.gfLow &&
        existing.gradientFactorHigh == state.gfHigh &&
        existing.diveMode == _diveMode(state.mode) &&
        existing.setpointLow == (_onLoop(state) ? state.setpointLow : null) &&
        existing.setpointHigh == (_onLoop(state) ? state.setpointHigh : null) &&
        existing.diluentGas == _diluent(state) &&
        _sameTanks(existing.tanks, state.tanks) &&
        _sameProfile(storedProfile, profile);
  }
}

bool _sameTanks(List<DiveTank> logged, List<DiveTank> planned) {
  if (logged.length != planned.length) return false;
  for (var i = 0; i < logged.length; i++) {
    final a = logged[i];
    final b = planned[i];
    if (a.name != b.name ||
        a.volume != b.volume ||
        a.workingPressure != b.workingPressure ||
        a.startPressure != b.startPressure ||
        a.endPressure != b.endPressure ||
        a.gasMix != b.gasMix ||
        a.role != b.role ||
        a.material != b.material) {
      return false;
    }
  }
  return true;
}

bool _sameProfile(List<DiveProfilePoint> stored, List<DiveProfilePoint> next) {
  if (stored.length != next.length) return false;
  for (var i = 0; i < stored.length; i++) {
    if (stored[i].timestamp != next[i].timestamp ||
        (stored[i].depth - next[i].depth).abs() > _depthTolerance) {
      return false;
    }
  }
  return true;
}

/// Each dive's entry in the log, by its index in [series]: the dive its
/// plan row links, or the series' own link for a dive not saved yet. Null
/// for a dive with no link, or one whose entry has since been deleted. The
/// rows are read rather than the series in memory, which can hold a stale
/// link for a dive linked while another was in the editor.
Future<Map<int, Dive?>> linkedEntries(
  PlanSeries series,
  DivePlanRepository plans,
  DiveRepository dives,
) async {
  final linked = <int, Dive?>{};
  for (final (i, dive) in series.dives.indexed) {
    final row = await plans.getPlan(dive.state.id);
    final id = row == null ? dive.state.linkedDiveId : row.linkedDiveId;
    linked[i] = id == null ? null : await dives.getDiveById(id);
  }
  return linked;
}

/// The log's mode for a plan's: every rebreather but a closed circuit is
/// semi-closed there.
DiveMode _diveMode(PlanMode mode) => switch (mode) {
  PlanMode.oc => DiveMode.oc,
  PlanMode.ccr => DiveMode.ccr,
  PlanMode.scr || PlanMode.pscr => DiveMode.scr,
};

bool _onLoop(DivePlanState state) => state.mode == PlanMode.ccr;

/// A rebreather plan's diluent, the first diluent cylinder's mix, which the
/// log's deco model and gas timeline breathe on the loop.
GasMix? _diluent(DivePlanState state) {
  if (state.mode == PlanMode.oc) return null;
  for (final tank in state.tanks) {
    if (tank.role == TankRole.diluent) return tank.gasMix;
  }
  return null;
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

/// [site] when it may go on a dive of [diverId]. Saved plans are not
/// diver-scoped, so the plan may name a site private to another diver. A
/// shared site or one the diver owns qualifies, the rule the site list
/// applies (a site shared with this diver by name, or in a shared site
/// library, counts too, issue #2151), except that with no diver the dive is
/// unowned, where only an unowned site does. A site deleted since the plan
/// was saved resolves to null and is left off.
Future<DiveSite?> visiblePlanSite(
  DiveSite? site,
  String? diverId,
  ItemSharesRepository shares,
) async {
  if (site == null) return null;
  if (diverId == null) {
    return site.isShared || site.diverId == null ? site : null;
  }
  if (site.diverId == diverId || site.isShared) return site;
  final shared = await shares.isVisibleTo(
    SharedItemKind.site,
    site.id,
    diverId,
  );
  return shared ? site : null;
}
