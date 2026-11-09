import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_series_settings.dart';

/// The planner's series for [stored], following [follow] with
/// [selectedIndex] selected. Nothing in it is unsaved.
PlanSeries seriesFromStored(
  StoredSeries stored, {
  required SeriesFollow? follow,
  required int selectedIndex,
}) {
  final dives = [
    for (final dive in stored.dives)
      PlanSeriesDive(
        state: stateFromDivePlan(dive.plan).copyWith(isDirty: false),
        name: dive.name,
        sourceTankIds: dive.sourceTankIds,
        pinnedTankIds: dive.pinnedTankIds,
        fixedStart: dive.fixedStart,
        settingOverrides: dive.settingOverrides,
      ),
  ];
  final first = dives.first.state;
  return PlanSeries(
    id: stored.id,
    follow: follow,
    selectedIndex: selectedIndex,
    dives: [
      // The first dive's settings are the series'; a later one keeps every
      // group whose values are not the series', said so or not.
      for (final (index, dive) in dives.indexed)
        index == 0
            ? dive.copyWith(settingOverrides: const {})
            : dive.copyWith(settingOverrides: ownSettingGroups(first, dive)),
    ],
  );
}

/// [follow] with the first dive's own pressures, which are not stored: each
/// tank taken from the logged dive fills to what that tank started with.
SeriesFollow withOwnPressures(SeriesFollow follow, StoredSeries stored) {
  final first = stored.dives.first;
  final logged = {for (final tank in follow.endTanks) tank.id: tank};
  return follow.copyWith(
    ownStartPressures: {
      for (final tank in first.plan.tanks)
        tank.id:
            ?(logged[first.sourceTankIds[tank.id]]?.startPressure ??
            logged[first.sourceTankIds[tank.id]]?.workingPressure ??
            tank.startPressure),
    },
  );
}
