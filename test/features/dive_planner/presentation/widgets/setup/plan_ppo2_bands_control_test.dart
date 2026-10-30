import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_ppo2_bands_control.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Slider _slider(WidgetTester tester, int index) =>
    tester.widgetList<Slider>(find.byType(Slider)).elementAt(index);

void main() {
  group('PlanPpO2BandsControl', () {
    testWidgets(
      'Default state shows the Settings band values as read-only text, one '
      'per line, and no sliders',
      (tester) async {
        await tester.pumpWidget(
          _app(
            PlanPpO2BandsControl(
              band1: null,
              band2: null,
              band3: null,
              explicitlyOff: false,
              defaultBand1: 1.35,
              defaultBand2: 1.45,
              defaultBand3: 1.55,
              bandsEnabledInSettings: true,
              onBand1Changed: (_) {},
              onBand2Changed: (_) {},
              onBand3Changed: (_) {},
              onOff: (_) {},
              onDefault: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ChoiceChip, 'Default'), findsOneWidget);
        expect(find.textContaining('1.35 bar'), findsOneWidget);
        expect(find.textContaining('1.45 bar'), findsOneWidget);
        expect(find.textContaining('1.55 bar'), findsOneWidget);
        expect(find.byType(Slider), findsNothing);
      },
    );

    testWidgets(
      'Default state shows Off when the Settings band toggle itself is off',
      (tester) async {
        await tester.pumpWidget(
          _app(
            PlanPpO2BandsControl(
              band1: null,
              band2: null,
              band3: null,
              explicitlyOff: false,
              defaultBand1: 1.35,
              defaultBand2: 1.45,
              defaultBand3: 1.55,
              bandsEnabledInSettings: false,
              onBand1Changed: (_) {},
              onBand2Changed: (_) {},
              onBand3Changed: (_) {},
              onOff: (_) {},
              onDefault: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The "Default" chip is selected, but the Settings toggle being off
        // means there's nothing to resolve to - distinct from this plan's
        // own "Off" choice, both of which read "Off".
        expect(find.text('Off'), findsNWidgets(2));
      },
    );

    testWidgets('selecting Off sets explicitlyOff and hides all values', (
      tester,
    ) async {
      bool? offValue;
      await tester.pumpWidget(
        _app(
          PlanPpO2BandsControl(
            band1: null,
            band2: null,
            band3: null,
            explicitlyOff: false,
            defaultBand1: 1.35,
            defaultBand2: 1.45,
            defaultBand3: 1.55,
            bandsEnabledInSettings: true,
            onBand1Changed: (_) {},
            onBand2Changed: (_) {},
            onBand3Changed: (_) {},
            onOff: (v) => offValue = v,
            onDefault: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Off'));
      await tester.pumpAndSettle();

      expect(offValue, isTrue);
    });

    testWidgets(
      'selecting Custom seeds all three bands from the Settings defaults and '
      'shows editable sliders',
      (tester) async {
        final changed = <int, double>{};
        await tester.pumpWidget(
          _app(
            PlanPpO2BandsControl(
              band1: null,
              band2: null,
              band3: null,
              explicitlyOff: false,
              defaultBand1: 1.35,
              defaultBand2: 1.45,
              defaultBand3: 1.55,
              bandsEnabledInSettings: true,
              onBand1Changed: (v) => changed[1] = v,
              onBand2Changed: (v) => changed[2] = v,
              onBand3Changed: (v) => changed[3] = v,
              onOff: (_) {},
              onDefault: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
        await tester.pumpAndSettle();

        expect(changed[1], 1.35);
        expect(changed[2], 1.45);
        expect(changed[3], 1.55);
      },
    );

    testWidgets('Custom state shows three sliders bound to the plan values', (
      tester,
    ) async {
      double? newBand2;
      await tester.pumpWidget(
        _app(
          PlanPpO2BandsControl(
            band1: 1.3,
            band2: 1.4,
            band3: 1.5,
            explicitlyOff: false,
            defaultBand1: 1.35,
            defaultBand2: 1.45,
            defaultBand3: 1.55,
            bandsEnabledInSettings: true,
            onBand1Changed: (_) {},
            onBand2Changed: (v) => newBand2 = v,
            onBand3Changed: (_) {},
            onOff: (_) {},
            onDefault: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Custom'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(3));
      expect(_slider(tester, 0).value, 1.3);
      expect(_slider(tester, 1).value, 1.4);
      expect(_slider(tester, 2).value, 1.5);

      _slider(tester, 1).onChanged!(1.5);
      expect(newBand2, 1.5);
    });

    testWidgets('selecting Default clears every override at once', (
      tester,
    ) async {
      var defaultCalled = false;
      await tester.pumpWidget(
        _app(
          PlanPpO2BandsControl(
            band1: 1.3,
            band2: 1.4,
            band3: 1.5,
            explicitlyOff: false,
            defaultBand1: 1.35,
            defaultBand2: 1.45,
            defaultBand3: 1.55,
            bandsEnabledInSettings: true,
            onBand1Changed: (_) {},
            onBand2Changed: (_) {},
            onBand3Changed: (_) {},
            onOff: (_) {},
            onDefault: () => defaultCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Default'));
      await tester.pumpAndSettle();

      expect(defaultCalled, isTrue);
    });
  });

  group('PlanMaxO2DepthControl', () {
    testWidgets('Default state shows the Settings depth in meters', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          PlanMaxO2DepthControl(
            maxO2DepthMeters: null,
            explicitlyOff: false,
            defaultMaxO2DepthMeters: 6.0,
            enabledInSettings: true,
            units: const UnitFormatter(AppSettings()),
            onChanged: (_) {},
            onOff: (_) {},
            onDefault: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('6.0m'), findsOneWidget);
    });

    testWidgets(
      'Default state converts the Settings depth to the diver\'s unit '
      '(issue #3580 follow-up)',
      (tester) async {
        await tester.pumpWidget(
          _app(
            PlanMaxO2DepthControl(
              maxO2DepthMeters: null,
              explicitlyOff: false,
              defaultMaxO2DepthMeters: 6.0,
              enabledInSettings: true,
              units: const UnitFormatter(
                AppSettings(depthUnit: DepthUnit.feet),
              ),
              onChanged: (_) {},
              onOff: (_) {},
              onDefault: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 6.0 m == 19.68 ft, rounded to one decimal.
        expect(find.text('19.7ft'), findsOneWidget);
        expect(find.text('6.0m'), findsNothing);
      },
    );

    testWidgets('Default state shows Off when the Settings toggle is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          PlanMaxO2DepthControl(
            maxO2DepthMeters: null,
            explicitlyOff: false,
            defaultMaxO2DepthMeters: 6.0,
            enabledInSettings: false,
            units: const UnitFormatter(AppSettings()),
            onChanged: (_) {},
            onOff: (_) {},
            onDefault: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Off'), findsNWidgets(2));
    });

    testWidgets('selecting Custom seeds the override from the Settings '
        'default', (tester) async {
      double? seeded;
      await tester.pumpWidget(
        _app(
          PlanMaxO2DepthControl(
            maxO2DepthMeters: null,
            explicitlyOff: false,
            defaultMaxO2DepthMeters: 6.0,
            enabledInSettings: true,
            units: const UnitFormatter(AppSettings()),
            onChanged: (v) => seeded = v,
            onOff: (_) {},
            onDefault: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
      await tester.pumpAndSettle();

      expect(seeded, 6.0);
    });

    testWidgets('Custom state shows a slider in meters with a unit-aware '
        'label bound to the plan value', (tester) async {
      double? newValue;
      await tester.pumpWidget(
        _app(
          PlanMaxO2DepthControl(
            maxO2DepthMeters: 6.0,
            explicitlyOff: false,
            defaultMaxO2DepthMeters: 6.0,
            enabledInSettings: true,
            units: const UnitFormatter(AppSettings(depthUnit: DepthUnit.feet)),
            onChanged: (v) => newValue = v,
            onOff: (_) {},
            onDefault: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Custom'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      // The slider's own grid stays in meters; only the label converts.
      expect(_slider(tester, 0).value, 6.0);
      expect(find.text('19.7ft'), findsOneWidget);

      _slider(tester, 0).onChanged!(7.0);
      expect(newValue, 7.0);
    });

    testWidgets('selecting Off reports explicitlyOff for this plan', (
      tester,
    ) async {
      bool? offValue;
      await tester.pumpWidget(
        _app(
          PlanMaxO2DepthControl(
            maxO2DepthMeters: null,
            explicitlyOff: false,
            defaultMaxO2DepthMeters: 6.0,
            enabledInSettings: true,
            units: const UnitFormatter(AppSettings()),
            onChanged: (_) {},
            onOff: (v) => offValue = v,
            onDefault: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Off'));
      await tester.pumpAndSettle();

      expect(offValue, isTrue);
    });
  });
}
