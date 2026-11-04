import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/plan_series_tanks.dart';
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
  required String Function() newId,
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
  return followFirstDive(series, changed, newId: newId);
}

/// [series] with every later dive that does not override them taking the
/// first dive's values of [groups]: after the first dive's values change,
/// or after another dive becomes the first and its own values the series'.
PlanSeries followFirstDive(
  PlanSeries series,
  Set<PlanSettingGroup> groups, {
  required String Function() newId,
}) {
  if (groups.isEmpty || series.dives.length < 2) return series;
  final first = series.dives.first;
  final shared = series.copyWith(
    dives: [
      first,
      for (final dive in series.dives.skip(1)) _follow(dive, first, groups),
    ],
  );
  return groups.contains(PlanSettingGroup.tanks)
      ? followSeriesTanks(shared, newId: newId)
      : shared;
}

/// The groups [dive], a later dive of a series whose first dive is [first],
/// keeps its own: those it says it overrides, and any whose values differ
/// from the first dive's. A dive saved before a series shared its settings
/// (or read from such a file) says nothing yet may hold values of its own;
/// taking them for the series' would lose them at the next edit of the
/// first dive. Tanks on another circuit are never shared, so they are left
/// as the dive says.
Set<PlanSettingGroup> ownSettingGroups(
  DivePlanState first,
  PlanSeriesDive dive,
) {
  final sameCircuit = dive.state.mode == first.mode;
  return {
    ...dive.settingOverrides,
    for (final group in changedGroups(first, dive.state))
      if (group != PlanSettingGroup.tanks || sameCircuit) group,
  };
}

/// The dive at [index] back on the series' values of [group].
PlanSeries resetGroupToSeries(
  PlanSeries series,
  int index,
  PlanSettingGroup group, {
  required String Function() newId,
}) {
  if (index == 0) return series;
  final dive = series.dives[index];
  final reset = _replace(
    series,
    index,
    dive.copyWith(
      state: applyGroup(group, from: series.dives.first.state, to: dive.state),
      settingOverrides: {...dive.settingOverrides}..remove(group),
    ),
  );
  return group == PlanSettingGroup.tanks
      ? followSeriesTanks(reset, newId: newId)
      : reset;
}

/// The values of [group] on the dive at [index] made the series': the first
/// dive and every dive that does not override the group take them, and the
/// dive no longer overrides it.
PlanSeries applyGroupToAll(
  PlanSeries series,
  int index,
  PlanSettingGroup group, {
  required String Function() newId,
}) {
  if (group == PlanSettingGroup.tanks) {
    final dive = series.dives[index];
    final taken = firstDiveTakesTanks(series, index, newId: newId);
    return followSeriesTanks(
      index == 0
          ? taken
          : _replace(
              taken,
              index,
              dive.copyWith(
                settingOverrides: {...dive.settingOverrides}..remove(group),
              ),
            ),
      newId: newId,
    );
  }
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
