import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/plan_setting_groups.dart';

/// Settings shared across a repetitive series (issue #3565). The first
/// dive's settings are the series'. Each edit returns a new series; none
/// mutates the one it is given.

/// Shares what an edit to the dive at [index] changed, from [before]: the
/// dive's state before the edit, the edited one already stored.
///
/// On the first dive, each changed group is the series' new value, so every
/// later dive that does not override it takes it. On a later dive, each
/// changed group becomes that dive's own.
PlanSeries shareSettingEdits(
  PlanSeries series,
  int index, {
  required DivePlanState before,
}) {
  final edited = series.dives[index];
  final changed = changedGroups(before, edited.state);
  if (changed.isEmpty) return series;

  if (index > 0) {
    return _replace(
      series,
      index,
      edited.copyWith(
        settingOverrides: {...edited.settingOverrides, ...changed},
      ),
    );
  }
  return series.copyWith(
    dives: [
      edited,
      for (final dive in series.dives.skip(1)) _follow(dive, edited, changed),
    ],
  );
}

/// The dive at [index] back on the series' values of [group].
PlanSeries resetGroupToSeries(
  PlanSeries series,
  int index,
  PlanSettingGroup group,
) {
  if (index == 0) return series;
  final dive = series.dives[index];
  return _replace(
    series,
    index,
    dive.copyWith(
      state: applyGroup(group, from: series.dives.first.state, to: dive.state),
      settingOverrides: {...dive.settingOverrides}..remove(group),
    ),
  );
}

/// The values of [group] on the dive at [index] made the series': the first
/// dive and every dive that does not override the group take them, and the
/// dive no longer overrides it.
PlanSeries applyGroupToAll(
  PlanSeries series,
  int index,
  PlanSettingGroup group,
) {
  final source = series.dives[index];
  final first = series.dives.first;
  final dives = [
    first.copyWith(
      state: applyGroup(group, from: source.state, to: first.state),
    ),
    for (var i = 1; i < series.dives.length; i++)
      if (i == index)
        source.copyWith(
          settingOverrides: {...source.settingOverrides}..remove(group),
        )
      else
        _follow(series.dives[i], source, {group}),
  ];
  return series.copyWith(dives: dives);
}

/// Whether the dive at [index] keeps its own values of [group].
bool overridesGroup(PlanSeries series, int index, PlanSettingGroup group) =>
    series.dives[index].settingOverrides.contains(group);

/// [dive] with the values of the [groups] it does not override taken from
/// [source].
PlanSeriesDive _follow(
  PlanSeriesDive dive,
  PlanSeriesDive source,
  Set<PlanSettingGroup> groups,
) {
  var state = dive.state;
  for (final group in groups) {
    if (dive.settingOverrides.contains(group)) continue;
    state = applyGroup(group, from: source.state, to: state);
  }
  return identical(state, dive.state) ? dive : dive.copyWith(state: state);
}

PlanSeries _replace(PlanSeries series, int index, PlanSeriesDive dive) {
  final dives = [...series.dives];
  dives[index] = dive;
  return series.copyWith(dives: dives);
}
