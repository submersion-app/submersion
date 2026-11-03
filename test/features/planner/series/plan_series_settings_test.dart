import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/plan_series_edits.dart';
import 'package:submersion/features/planner/domain/services/plan_series_settings.dart';
import 'package:submersion/features/planner/domain/services/plan_setting_groups.dart';

import 'series_fixtures.dart';

/// Dives A, B and C, every one on GF 40/80.
PlanSeries _threeDives() {
  final ids = idSequence();
  var series = PlanSeries.single(seriesDiveState());
  series = appendDive(series, newId: ids);
  return appendDive(series, newId: ids);
}

/// The series after the dive at [index] is edited to GF [low]/[high].
PlanSeries _editGf(PlanSeries series, int index, int low, int high) {
  final before = series.dives[index].state;
  final edited = updateDiveState(
    series,
    index,
    before.copyWith(gfLow: low, gfHigh: high),
  );
  return shareSettingEdits(edited, index, before: before);
}

void main() {
  test('editing the first dive changes every dive that follows it', () {
    final series = _editGf(_threeDives(), 0, 30, 70);

    for (final dive in series.dives) {
      expect(dive.state.gfLow, 30);
      expect(dive.state.gfHigh, 70);
    }
  });

  test('editing a later dive overrides that group on that dive only', () {
    final series = _editGf(_threeDives(), 1, 50, 85);

    expect(series.dives[1].settingOverrides, {PlanSettingGroup.deco});
    expect(series.dives[0].state.gfLow, 40);
    expect(series.dives[2].state.gfLow, 40);
  });

  test('a dive with its own value keeps it when the series changes', () {
    var series = _editGf(_threeDives(), 1, 50, 85);
    series = _editGf(series, 0, 30, 70);

    expect(series.dives[1].state.gfLow, 50);
    expect(series.dives[2].state.gfLow, 30);
  });

  test('an edit outside every group overrides nothing', () {
    final series = _threeDives();
    final before = series.dives[1].state;
    final edited = updateDiveState(series, 1, before.copyWith(notes: 'Wreck'));

    expect(
      shareSettingEdits(edited, 1, before: before).dives[1].settingOverrides,
      isEmpty,
    );
  });

  test('Reset to series takes the first dive\'s values back', () {
    var series = _editGf(_threeDives(), 1, 50, 85);
    series = resetGroupToSeries(series, 1, PlanSettingGroup.deco);

    expect(series.dives[1].state.gfLow, 40);
    expect(series.dives[1].settingOverrides, isEmpty);
  });

  test('Apply to all dives makes a dive\'s values the series\'', () {
    var series = _editGf(_threeDives(), 2, 50, 85);
    series = _editGf(series, 1, 35, 75);
    series = applyGroupToAll(series, 1, PlanSettingGroup.deco);

    expect(series.dives[0].state.gfLow, 35);
    expect(series.dives[1].settingOverrides, isEmpty);
    // Dive C keeps the value it chose for itself.
    expect(series.dives[2].state.gfLow, 50);
  });

  test('removing the first dive makes the next one the series', () {
    var series = _editGf(_threeDives(), 1, 50, 85);
    series = removeDive(series, 0);

    expect(series.dives[0].settingOverrides, isEmpty);
  });

  test('a new dive takes the overrides of the dive it copies', () {
    var series = _editGf(_threeDives(), 2, 50, 85);
    series = appendDive(series, newId: idSequence('d'));

    expect(series.dives[3].settingOverrides, {PlanSettingGroup.deco});
    expect(series.dives[3].state.gfLow, 50);
  });
}
