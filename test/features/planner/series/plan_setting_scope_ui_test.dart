import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_setting_group.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_setting_scope.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_database.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Settings shared across a series, through the editor (issue #3565).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlanCanvasPage)));

  Future<void> pumpPlan(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
        ],
        locale: const Locale('en'),
        child: const PlanCanvasPage(),
      ),
    );
    containerOf(tester)
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
  }

  PlanSeriesNotifier series(WidgetTester tester) =>
      containerOf(tester).read(planSeriesNotifierProvider.notifier);
  DivePlanNotifier editor(WidgetTester tester) =>
      containerOf(tester).read(divePlanNotifierProvider.notifier);
  Finder scope() => find.byKey(const ValueKey('settingScope_deco'));
  String scopeText(WidgetTester tester) => tester.widget<Text>(scope()).data!;

  testWidgets('a single dive shows no scope', (tester) async {
    await pumpPlan(tester);
    expect(find.byType(PlanSettingScopeLabel), findsWidgets);
    expect(scope(), findsNothing);
  });

  testWidgets('labels follow the dive and its edits', (tester) async {
    await pumpPlan(tester);
    series(tester).addDive();
    await tester.pumpAndSettle();
    expect(scopeText(tester), 'From the series');

    editor(tester).updateGradientFactors(50, 85);
    await tester.pumpAndSettle();
    expect(scopeText(tester), 'This dive only');

    series(tester).select(0);
    await tester.pumpAndSettle();
    expect(scopeText(tester), 'Series');
  });

  testWidgets('an edit on Dive A reaches a dive taking the series value', (
    tester,
  ) async {
    await pumpPlan(tester);
    series(tester).addDive();
    series(tester).select(0);
    await tester.pumpAndSettle();

    editor(tester).updateGradientFactors(30, 70);
    await tester.pumpAndSettle();
    series(tester).select(1);
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(divePlanNotifierProvider).gfLow, 30);
  });

  testWidgets('Reset and Apply act on the selected dive', (tester) async {
    await pumpPlan(tester);
    final firstGf = containerOf(tester).read(divePlanNotifierProvider).gfLow;
    series(tester).addDive();
    editor(tester).updateGradientFactors(50, 85);
    await tester.pumpAndSettle();

    series(tester).resetGroupToSeries(PlanSettingGroup.deco);
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(divePlanNotifierProvider).gfLow, firstGf);
    expect(scopeText(tester), 'From the series');

    editor(tester).updateGradientFactors(50, 85);
    series(tester).applyGroupToAll(PlanSettingGroup.deco);
    await tester.pumpAndSettle();
    final dives = containerOf(tester).read(planSeriesNotifierProvider).dives;
    expect(dives[0].state.gfLow, 50);
    expect(dives[1].settingOverrides, isEmpty);
  });
}
