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
    // Declaration order in PlanGasOptionsSection: Deco RMV, stressed RMV
    // (issue #3552), RMV factor, problem solving time, gas switch stop,
    // ppO2 bottom, ppO2 deco, best-mix END.
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(8));
    expect(fields.first.decoration?.hintText, '15');

    await tester.enterText(find.byType(TextField).at(2), '3');
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).sacFactor, 3.0);
  });

  testWidgets('stressed RMV is an absolute rate, hinted from Settings', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasOptionsSection)),
    );
    final stressed = tester.widgetList<TextField>(find.byType(TextField));
    // Unset: bottom RMV 15 (Settings) times the 2.5 Settings factor.
    expect(stressed.elementAt(1).decoration?.hintText, '37.5');

    await tester.enterText(find.byType(TextField).at(1), '45');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).sacStressed, 45.0);

    // A later bottom RMV change leaves the typed value exactly as typed,
    // instead of re-deriving it as a drifting multiple.
    container.read(divePlanNotifierProvider.notifier).updateSacRate(20);
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).sacStressed, 45.0);
  });

  testWidgets('editing problem solving time updates the notifier state', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasOptionsSection)),
    );
    await tester.enterText(find.byType(TextField).at(3), '4');
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).problemSolvingMinutes, 4);
  });

  testWidgets('editing the gas switch stop updates the notifier state in '
      'seconds', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasOptionsSection)),
    );
    expect(
      container.read(divePlanNotifierProvider).gasSwitchStopSeconds,
      isNull,
    );

    await tester.enterText(find.byType(TextField).at(4), '2');
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).gasSwitchStopSeconds, 120);
  });

  testWidgets(
    'problem solving time shows the minute unit in the app language',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('de'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: const SingleChildScrollView(child: PlanGasOptionsSection()),
        ),
      );
      await tester.pumpAndSettle();

      // Problem solving time and the gas-switch stop time field both use
      // the same minute-unit suffix, so there are now two matches.
      expect(find.text('Min.'), findsNWidgets(2));
      expect(find.text('min'), findsNothing);
    },
  );

  testWidgets(
    'Default/On/Off choice for O2 narcotic updates the notifier state '
    '(issue #3552)',
    (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasOptionsSection)),
      );
      // A fresh plan has no override: "Default" is selected and the plan's
      // own field stays unset, following the diver's Settings default
      // (true in AppSettings()).
      expect(container.read(divePlanNotifierProvider).o2Narcotic, isNull);

      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      expect(container.read(divePlanNotifierProvider).o2Narcotic, isFalse);

      await tester.tap(find.text('On'));
      await tester.pumpAndSettle();
      expect(container.read(divePlanNotifierProvider).o2Narcotic, isTrue);

      // The Default chip shows the resolved value (issue #3552 follow-up):
      // AppSettings() defaults o2Narcotic to true.
      await tester.tap(find.text('Default (On)'));
      await tester.pumpAndSettle();
      expect(container.read(divePlanNotifierProvider).o2Narcotic, isNull);
    },
  );

  testWidgets('best mix END shows meters by default', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // bestMixEndMeters is unset on a fresh plan (issue #3552): the field is
    // empty, following the diver's Settings default (30 m) as its hint.
    final bestMixField = tester.widget<TextField>(find.byType(TextField).last);
    expect(bestMixField.controller!.text, '');
    expect(bestMixField.decoration?.hintText, '30');
  });

  testWidgets('best mix END shows feet when the depth unit is imperial', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(depthUnit: DepthUnit.feet));
    await tester.pumpAndSettle();

    // 30 m == ~98 ft, shown as the hint since the field is unset.
    final bestMixField = tester.widget<TextField>(find.byType(TextField).last);
    expect(bestMixField.decoration?.hintText, '98');

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
