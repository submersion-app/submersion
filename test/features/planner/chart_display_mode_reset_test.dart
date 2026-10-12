import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';

/// The chart's Bailout/CCR toggle belongs to the plan it was chosen on. It
/// resets on its own when the plan changes, with no chart mounted: a diver
/// who leaves the canvas, opens another plan and comes back must not land on
/// a Bailout view they never chose for that plan (#3130 follow-up).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    container.read(divePlanNotifierProvider.notifier).updateMode(PlanMode.ccr);
    container.read(chartDisplayModeProvider.notifier).state =
        ChartDisplayMode.bailout;
    return container;
  }

  test('opening a different plan resets the toggle to CCR', () async {
    final container = await makeContainer();

    container.read(divePlanNotifierProvider.notifier).newPlan();

    expect(container.read(chartDisplayModeProvider), ChartDisplayMode.ccr);
  });

  test('changing the plan mode resets the toggle to CCR', () async {
    final container = await makeContainer();

    container.read(divePlanNotifierProvider.notifier).updateMode(PlanMode.oc);

    expect(container.read(chartDisplayModeProvider), ChartDisplayMode.ccr);
  });

  test('an ordinary edit to the same plan keeps the Bailout view', () async {
    final container = await makeContainer();

    container.read(divePlanNotifierProvider.notifier).updateName('Renamed');

    expect(container.read(chartDisplayModeProvider), ChartDisplayMode.bailout);
  });
}
