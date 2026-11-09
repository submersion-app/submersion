import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/domain/services/stored_series_mapper.dart';

/// Reads the logged dive [diveId] as a series following it would: the dive
/// and those before it, with what it leaves behind. Null when it is gone.
/// The planner reads it through `seriesFollowProvider`.
typedef SeriesFollowReader = Future<SeriesFollow?> Function(String diveId);

/// What the log says about [links], (plan id, dive id) pairs, by plan id:
/// for each entry no longer planned, the dive as a followed dive reads.
/// Shared by the planner's `seriesActualsProvider`, opening a saved plan,
/// which reads it before the plan shows so a dived dive never shows as a
/// plan first, and [computeStoredSeries].
Future<Map<String, SeriesFollow>> readSeriesActuals(
  Iterable<(String, String)> links,
  DiveRepository repository,
  SeriesFollowReader followOf,
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

/// A saved series computed as the planner computes it on opening (issue
/// #4203): carrying in what the dive it follows left behind, as that dive
/// is now, and each dive that has been dived taken as dived. Computed with
/// [config], the settings of whoever it is computed for, so it can differ
/// from the summary stored when it was saved.
///
/// What opening it in the planner shows, without the planner: the series as
/// the planner holds it, and each dive's result in order.
Future<({PlanSeries series, List<SeriesDiveResult> results})>
computeStoredSeries(
  StoredSeries stored, {
  required PlanEngineConfig config,
  required DiveRepository dives,
  required SeriesFollowReader followOf,
}) async {
  final followedId = stored.followedDiveId;
  final follow = followedId == null ? null : await followOf(followedId);
  final actuals = await readSeriesActuals(
    [
      for (final dive in stored.dives)
        if (dive.plan.linkedDiveId case final id?) (dive.plan.id, id),
    ],
    dives,
    followOf,
  );
  final opened = seriesFromStored(
    stored,
    follow: follow == null ? null : withOwnPressures(follow, stored),
    selectedIndex: 0,
  );
  final series = _withActuals(opened, actuals);
  return (
    series: series,
    results: computeSeries(series.dives, config: config, follow: series.follow),
  );
}

/// A saved plan that is in no series, computed as the planner computes it,
/// and taken as dived if its dive has been.
Future<({PlanSeries series, List<SeriesDiveResult> results})> computeStoredPlan(
  DivePlan plan, {
  required PlanEngineConfig config,
  required DiveRepository dives,
  required SeriesFollowReader followOf,
}) async {
  final actuals = await readSeriesActuals(
    [if (plan.linkedDiveId case final id?) (plan.id, id)],
    dives,
    followOf,
  );
  final series = _withActuals(
    PlanSeries.single(stateFromDivePlan(plan).copyWith(isDirty: false)),
    actuals,
  );
  return (series: series, results: computeSeries(series.dives, config: config));
}

/// [series] with each dive that has been dived holding what it left behind,
/// as the planner's series takes them.
PlanSeries _withActuals(PlanSeries series, Map<String, SeriesFollow> actuals) =>
    series.copyWith(
      dives: [
        for (final dive in series.dives)
          if (actuals[dive.state.id] case final actual?)
            dive.copyWith(actual: actual)
          else
            dive,
      ],
    );
