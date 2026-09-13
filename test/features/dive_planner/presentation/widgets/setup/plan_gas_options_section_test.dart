import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_gas_options_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier({DepthUnit depthUnit = DepthUnit.meters})
    : super(AppSettings(depthUnit: depthUnit));

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness({DepthUnit depthUnit = DepthUnit.meters}) => testApp(
  locale: const Locale('en'),
  overrides: [
    settingsProvider.overrideWith(
      (ref) => _TestSettingsNotifier(depthUnit: depthUnit),
    ),
  ],
  child: const SingleChildScrollView(child: PlanGasOptionsSection()),
);

void main() {
  testWidgets('editing the RMV factor updates the notifier state', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasOptionsSection)),
    );
    // Declaration order in PlanGasOptionsSection: Deco RMV, RMV factor,
    // problem solving time, ppO2 bottom, ppO2 deco, best-mix END.
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(6));
    expect(fields.first.decoration?.hintText, '15');

    await tester.enterText(find.byType(TextField).at(1), '3');
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).sacFactor, 3.0);
  });

  testWidgets('editing problem solving time updates the notifier state', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasOptionsSection)),
    );
    await tester.enterText(find.byType(TextField).at(2), '4');
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).problemSolvingMinutes, 4);
  });

  testWidgets('toggling O2 narcotic updates the notifier state', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasOptionsSection)),
    );
    // AppSettings default is true; the plan has no override yet, so the
    // switch reflects the global default.
    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isTrue);
    expect(container.read(divePlanNotifierProvider).o2Narcotic, isNull);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).o2Narcotic, isFalse);
  });

  testWidgets('best mix END shows meters by default', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // bestMixEndMeters defaults to 30 m; the last field is Best mix END.
    final bestMixField = tester.widget<TextField>(find.byType(TextField).last);
    expect(bestMixField.controller!.text, '30');
  });

  testWidgets('best mix END shows feet when the depth unit is imperial', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(depthUnit: DepthUnit.feet));
    await tester.pumpAndSettle();

    // 30 m == ~98 ft.
    final bestMixField = tester.widget<TextField>(find.byType(TextField).last);
    expect(bestMixField.controller!.text, '98');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasOptionsSection)),
    );
    await tester.enterText(find.byType(TextField).last, '100');
    await tester.pumpAndSettle();

    // Stored in meters regardless of the display unit.
    expect(
      container.read(divePlanNotifierProvider).bestMixEndMeters,
      closeTo(100 / 3.28084, 0.01),
    );
  });
}
