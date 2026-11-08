import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/deco_calculator/presentation/pages/deco_calculator_page.dart';
import 'package:submersion/features/deco_calculator/presentation/providers/deco_calculator_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  /// Pumps the real calculator page with the planner route replaced by a
  /// placeholder, so the shared planner state can be read after the tap.
  Future<ProviderContainer> pumpCalculator(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => _FixedSettings())],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/calculator',
      routes: [
        GoRoute(
          path: '/calculator',
          builder: (_, _) => const DecoCalculatorPage(),
        ),
        GoRoute(
          path: '/planning/dive-planner',
          builder: (_, _) => const Scaffold(body: Text('Planner destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapAddToPlanner(WidgetTester tester) async {
    // The action's icon, not its localized label, so a copy change does not
    // break the test.
    await tester.tap(find.byIcon(Icons.edit_calendar));
    await tester.pumpAndSettle();
    expect(find.text('Planner destination'), findsOneWidget);
    // Dismiss the confirmation SnackBar so its timer is not left pending at
    // teardown, whatever duration the page gives it.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  group('Add to Planner carries the calculator environment (#4314)', () {
    testWidgets('a fresh plan takes the selected altitude and water', (
      tester,
    ) async {
      final container = await pumpCalculator(tester);
      container.read(calcDepthProvider.notifier).state = 30;
      container.read(calcAltitudeProvider.notifier).state = 3000;
      container.read(calcWaterTypeProvider.notifier).state = WaterType.fresh;
      await tester.pump();

      await tapAddToPlanner(tester);

      final plan = container.read(divePlanNotifierProvider);
      expect(plan.altitude, 3000);
      expect(plan.waterType, WaterType.fresh);
      expect(plan.salinityPpt, isNull);
      expect(plan.segments.last.targetDepth, 30);
      // The planner's engine now computes in the conditions the calculator
      // showed, not sea-level salt water.
      expect(
        PlanEngine.environmentFor(divePlanFromState(plan)),
        container.read(calcEnvironmentProvider),
      );
    });

    testWidgets('an existing plan drops its old altitude and custom salinity', (
      tester,
    ) async {
      final container = await pumpCalculator(tester);
      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.updateAltitude(1500);
      notifier.updateSalinityPpt(70);
      notifier.addSimplePlan(maxDepth: 20, bottomTimeMinutes: 10);

      container.read(calcAltitudeProvider.notifier).state = 3000;
      container.read(calcWaterTypeProvider.notifier).state = WaterType.fresh;
      await tester.pump();

      await tapAddToPlanner(tester);

      final plan = container.read(divePlanNotifierProvider);
      expect(plan.altitude, 3000);
      expect(plan.waterType, WaterType.fresh);
      expect(
        plan.salinityPpt,
        isNull,
        reason: 'a leftover custom salinity would override Fresh Water',
      );
    });

    testWidgets('a below-sea-level altitude computes at its own surface '
        'pressure in the planner', (tester) async {
      final container = await pumpCalculator(tester);
      container.read(calcAltitudeProvider.notifier).state = -430;
      container.read(calcWaterTypeProvider.notifier).state = WaterType.salt;
      await tester.pump();

      await tapAddToPlanner(tester);

      final plan = container.read(divePlanNotifierProvider);
      expect(plan.altitude, -430);
      expect(
        PlanEngine.environmentFor(divePlanFromState(plan)),
        container.read(calcEnvironmentProvider),
        reason: 'the engine used to read -430 m as a 1.0 bar surface',
      );
    });

    testWidgets('a blank altitude is sea level and Standard water leaves the '
        "plan's water alone", (tester) async {
      final container = await pumpCalculator(tester);
      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.updateAltitude(1500);
      notifier.updateWaterType(WaterType.brackish);

      // Calculator defaults: altitude blank (sea level), water Standard.
      expect(container.read(calcAltitudeProvider), isNull);
      expect(container.read(calcWaterTypeProvider), isNull);

      await tapAddToPlanner(tester);

      final plan = container.read(divePlanNotifierProvider);
      expect(
        plan.altitude,
        isNull,
        reason: 'the calculator computed at sea level',
      );
      expect(
        plan.waterType,
        WaterType.brackish,
        reason: 'Standard (EN13319) has no planner preset to transfer',
      );
    });
  });
}
