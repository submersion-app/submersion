import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_setting_groups.dart';
import 'package:submersion/features/planner/domain/services/stored_series_mapper.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'series_fixtures.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Shared settings and tanks as the series notifier keeps them while the
/// diver edits (issue #3565).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 25);
    return container;
  }

  DivePlanState editor(ProviderContainer c) => c.read(divePlanNotifierProvider);
  DivePlanNotifier editing(ProviderContainer c) =>
      c.read(divePlanNotifierProvider.notifier);
  PlanSeriesNotifier series(ProviderContainer c) =>
      c.read(planSeriesNotifierProvider.notifier);

  test('removing Dive A gives the dives sharing the series the values Dive B '
      'kept its own', () async {
    final c = await makeContainer();
    series(c)
      ..addDive()
      ..addDive()
      ..select(1);
    editing(c).updateGradientFactors(30, 70);

    series(c).removeDive(0);

    final dives = c.read(planSeriesNotifierProvider).dives;
    expect(dives[0].settingOverrides, isEmpty);
    expect(dives[1].state.gfLow, 30);
    expect(dives[1].state.gfHigh, 70);
  });

  test('a tank changed to another gas on a later dive starts full in the '
      'editor, as the series computes it', () async {
    final c = await makeContainer();
    series(c).addDive();
    final tank = editor(c).tanks.first;
    // Carried from Dive A, so below its fill.
    expect(tank.startPressure, lessThan(200));

    editing(c).updateTank(tank.id, tank.copyWith(gasMix: const GasMix(o2: 32)));

    final full = tank.workingPressure;
    expect(editor(c).tanks.first.startPressure, full);
    expect(
      c.read(planSeriesResultsProvider)[1].state.tanks.first.startPressure,
      full,
    );
  });

  test('a dive saved before series shared settings keeps its own values as '
      'its own when opened', () {
    final a = seriesDiveState();
    final b = seriesDiveState(id: 'dive-b').copyWith(gfLow: 30, gfHigh: 70);
    final stored = StoredSeries(
      id: 's1',
      name: 'Reef day',
      dives: [
        StoredSeriesDive(plan: divePlanFromState(a)),
        StoredSeriesDive(plan: divePlanFromState(b)),
      ],
    );

    final opened = seriesFromStored(stored, follow: null, selectedIndex: 0);

    expect(opened.dives[0].settingOverrides, isEmpty);
    expect(opened.dives[1].settingOverrides, {PlanSettingGroup.deco});
    expect(opened.dives[1].state.gfLow, 30);
  });
}
