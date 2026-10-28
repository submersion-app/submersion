import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_choice_wrap.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_gas_options_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_ppo2_bands_control.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier({
    DepthUnit depthUnit = DepthUnit.meters,
    bool ppO2DecoBandsEnabled = false,
    double plannerHypercapniaFactor = 4.0,
    double ppO2MaxDeco = 1.6,
  }) : super(
         AppSettings(
           depthUnit: depthUnit,
           ppO2MaxDeco: ppO2MaxDeco,
           ppO2DecoBandsEnabled: ppO2DecoBandsEnabled,
           plannerHypercapniaEnabled: true,
           plannerHypercapniaFactor: plannerHypercapniaFactor,
         ),
       );

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness({
  DepthUnit depthUnit = DepthUnit.meters,
  bool ppO2DecoBandsEnabled = false,
  double plannerHypercapniaFactor = 4.0,
  double ppO2MaxDeco = 1.6,
}) => testApp(
  locale: const Locale('en'),
  overrides: [
    settingsProvider.overrideWith(
      (ref) => _TestSettingsNotifier(
        depthUnit: depthUnit,
        ppO2DecoBandsEnabled: ppO2DecoBandsEnabled,
        plannerHypercapniaFactor: plannerHypercapniaFactor,
        ppO2MaxDeco: ppO2MaxDeco,
      ),
    ),
  ],
  child: const SingleChildScrollView(child: PlanGasOptionsSection()),
);

void main() {
  testWidgets('with the Settings layers off, Custom starts from the flat '
      'deco ppO2 in force, not the untouched 1.6 bar column defaults '
      '(issue #3580)', (tester) async {
    await tester.pumpWidget(_harness(ppO2MaxDeco: 1.4));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasOptionsSection)),
    );

    // Bands first, then the explicit O2 depth (declaration order).
    await tester.tap(find.widgetWithText(ChoiceChip, 'Custom').first);
    await tester.pumpAndSettle();
    final depthCustom = find.widgetWithText(ChoiceChip, 'Custom').last;
    await tester.ensureVisible(depthCustom);
    await tester.pumpAndSettle();
    await tester.tap(depthCustom);
    await tester.pumpAndSettle();

    final state = container.read(divePlanNotifierProvider);
    expect(state.ppO2DecoBand1, closeTo(1.4, 1e-9));
    expect(state.ppO2DecoBand2, closeTo(1.4, 1e-9));
    expect(state.ppO2DecoBand3, closeTo(1.4, 1e-9));
    expect(state.maxO2DepthMeters, closeTo(4.0, 1e-9));
  });

  testWidgets('Custom seeds from a 2-decimal plan limit round down, never '
      'raising the ceiling (issue #3580)', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasOptionsSection)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .updateGasOptions(ppO2Deco: 1.58);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Custom').first);
    await tester.pumpAndSettle();
    final depthCustom = find.widgetWithText(ChoiceChip, 'Custom').last;
    await tester.ensureVisible(depthCustom);
    await tester.pumpAndSettle();
    await tester.tap(depthCustom);
    await tester.pumpAndSettle();

    final state = container.read(divePlanNotifierProvider);
    expect(state.ppO2DecoBand1, closeTo(1.5, 1e-9));
    // Pure O2 reaches 1.58 bar at 5.8 m; the 0.5 m grid floors it to 5.5.
    expect(state.maxO2DepthMeters, closeTo(5.5, 1e-9));
  });

  group('hypercapnia bailout phase (issue #3743)', () {
    testWidgets('an OC plan has no OC bailout, so no hypercapnia control', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Hypercapnia bailout phase'), findsNothing);
    });

    testWidgets('a loop plan shows it, its default never below the stressed '
        'rate the bailout falls back to', (tester) async {
      // Factor 2.0 sits below the 2.5 stressed factor.
      await tester.pumpWidget(_harness(plannerHypercapniaFactor: 2.0));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasOptionsSection)),
      );
      container
          .read(divePlanNotifierProvider.notifier)
          .updateMode(PlanMode.ccr);
      await tester.pumpAndSettle();

      expect(find.text('Hypercapnia bailout phase'), findsOneWidget);
      const settings = AppSettings();
      final stressed =
          settings.plannerSacBottom * settings.plannerSacStressedFactor;
      expect(
        find.textContaining('${stressed.toStringAsFixed(1)} L/min'),
        findsOneWidget,
      );
    });
  });

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

      // Scoped to this control's own chip row: the ppO2-band and max-depth
      // overrides below it (issue #3580) also show an "Off" chip, and now -
      // always rendered, not gated behind the Settings toggle - a plain
      // find.text('Off') is ambiguous.
      final o2NarcoticChoice = find.byType(PlanChoiceWrap<bool?>);
      await tester.ensureVisible(o2NarcoticChoice);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(of: o2NarcoticChoice, matching: find.text('Off')),
      );
      await tester.pumpAndSettle();
      expect(container.read(divePlanNotifierProvider).o2Narcotic, isFalse);

      await tester.tap(
        find.descendant(of: o2NarcoticChoice, matching: find.text('On')),
      );
      await tester.pumpAndSettle();
      expect(container.read(divePlanNotifierProvider).o2Narcotic, isTrue);

      // The Default chip shows the resolved value (issue #3552 follow-up):
      // AppSettings() defaults o2Narcotic to true.
      await tester.tap(
        find.descendant(
          of: o2NarcoticChoice,
          matching: find.text('Default (On)'),
        ),
      );
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

  testWidgets(
    'the ppO2-band control appears above Grund-ppO2 and Deco-ppO2 (issue '
    '#3580 follow-up)',
    (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final bandsControlTop = tester.getTopLeft(
        find.byType(PlanPpO2BandsControl),
      );
      final bottomPpO2Top = tester.getTopLeft(find.text('Bottom ppO₂'));
      expect(bandsControlTop.dy, lessThan(bottomPpO2Top.dy));
    },
  );

  testWidgets(
    'the flat Deco-ppO2 field is hidden while the Settings band toggle '
    'governs this plan (issue #3580 follow-up)',
    (tester) async {
      await tester.pumpWidget(_harness(ppO2DecoBandsEnabled: true));
      await tester.pumpAndSettle();

      expect(find.text('Deco ppO₂'), findsNothing);
    },
  );

  testWidgets(
    'the flat Deco-ppO2 field is shown again once this plan is explicitly '
    'Off, even with the Settings band toggle on (issue #3580 follow-up)',
    (tester) async {
      await tester.pumpWidget(_harness(ppO2DecoBandsEnabled: true));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasOptionsSection)),
      );
      container
          .read(divePlanNotifierProvider.notifier)
          .updateGasOptions(ppO2DecoBandsExplicitlyOff: true);
      await tester.pumpAndSettle();

      expect(find.text('Deco ppO₂'), findsOneWidget);
    },
  );

  testWidgets(
    'the flat Deco-ppO2 field is shown when the Settings band toggle itself '
    'is off (issue #3580 follow-up)',
    (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Deco ppO₂'), findsOneWidget);
    },
  );
}
