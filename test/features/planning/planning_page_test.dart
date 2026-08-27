import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/deco_calculator/presentation/providers/deco_calculator_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planning/presentation/pages/planning_page.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_summary_widget.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/features/safety/presentation/providers/no_fly_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('hub leads with New plan and recent saved plans', (tester) async {
    final summaries = [
      DivePlanSummary(
        id: 'p1',
        name: 'Reef 30m',
        updatedAt: DateTime(2026, 7, 4),
        maxDepth: 30.0,
        runtimeSeconds: 45 * 60,
        ttsSeconds: 300,
        mode: PlanMode.oc,
      ),
      DivePlanSummary(
        id: 'p2',
        name: 'Wreck 50m',
        updatedAt: DateTime(2026, 7, 3),
        maxDepth: 50.0,
        runtimeSeconds: 80 * 60,
        ttsSeconds: 2400,
        mode: PlanMode.ccr,
      ),
    ];

    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          divePlanSummariesProvider.overrideWith((ref) async => summaries),
        ],
        locale: const Locale('en'),
        child: const PlanningPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dive Planner'), findsOneWidget);
    expect(find.text('Create multi-level dive plans'), findsOneWidget);
    expect(find.text('Reef 30m'), findsOneWidget);
    expect(find.text('Wreck 50m'), findsOneWidget);
    expect(find.text('TOOLS'), findsOneWidget);
    // The calculators remain as tools.
    expect(find.text('Deco Calculator'), findsOneWidget);
  });

  group('hub navigation pushes sub-pages', () {
    // The hub's tools and saved plans are sub-pages: they must push, not go,
    // so the Android system back button pops back to the hub (#647).
    Future<GoRouter> pumpHub(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/planning',
        routes: [
          GoRoute(
            path: '/planning',
            builder: (_, _) => const PlanningPage(),
            routes: [
              GoRoute(
                path: 'deco-calculator',
                builder: (_, _) => const Text('deco calculator page'),
              ),
              GoRoute(
                path: 'dive-planner/:planId',
                builder: (context, state) =>
                    Text('plan:${state.pathParameters['planId']}'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        testAppRouter(
          router: router,
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            divePlanSummariesProvider.overrideWith(
              (ref) async => [
                DivePlanSummary(
                  id: 'p1',
                  name: 'Reef 30m',
                  updatedAt: DateTime(2026, 7, 4),
                  maxDepth: 30.0,
                  runtimeSeconds: 45 * 60,
                  ttsSeconds: 300,
                  mode: PlanMode.oc,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('tapping a tool pushes it over the hub', (tester) async {
      final router = await pumpHub(tester);

      await tester.tap(find.text('Deco Calculator'));
      await tester.pumpAndSettle();

      expect(find.text('deco calculator page'), findsOneWidget);
      expect(router.routerDelegate.canPop(), isTrue);
    });

    testWidgets('tapping a saved plan pushes it over the hub', (tester) async {
      final router = await pumpHub(tester);

      await tester.tap(find.text('Reef 30m'));
      await tester.pumpAndSettle();

      expect(find.text('plan:p1'), findsOneWidget);
      expect(router.routerDelegate.canPop(), isTrue);
    });
  });

  // On desktop the calculators open beside the hub instead of covering it, so
  // the tool list stays reachable. The dive planner is the exception: it has
  // its own three-pane layout and still needs the whole window.
  group('desktop split view', () {
    Future<GoRouter> pumpWide(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: '/planning',
        routes: [
          GoRoute(
            path: '/planning',
            builder: (_, _) => const PlanningPage(),
            routes: [
              GoRoute(
                path: 'dive-planner',
                builder: (_, _) => const Text('dive planner page'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        testAppRouter(
          router: router,
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            divePlanSummariesProvider.overrideWith(
              (ref) async => <DivePlanSummary>[],
            ),
            // The no-fly pane reaches a repository and a trip lookup, neither
            // of which exists in a widget test.
            noFlyStatusProvider.overrideWith((ref) async => null),
            activeTripFlightWindowProvider.overrideWith((ref) async => null),
          ],
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('shows the summary pane before a tool is chosen', (
      tester,
    ) async {
      await pumpWide(tester);

      expect(find.text('Select a tool to get started'), findsOneWidget);
      expect(find.text('SAVED PLANS'), findsOneWidget);
      // Genuinely no plans in this fixture, so the empty state is accurate.
      expect(find.text('No saved plans yet'), findsOneWidget);
    });

    // "No saved plans yet" is a claim about the data. Asserting it before the
    // query has answered tells a diver with a full plan library that they
    // have none, which is worse than showing nothing for a frame.
    testWidgets('does not claim "no plans" while the query is in flight', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: '/planning',
        routes: [
          GoRoute(path: '/planning', builder: (_, _) => const PlanningPage()),
        ],
      );
      addTearDown(router.dispose);

      final gate = Completer<List<DivePlanSummary>>();
      await tester.pumpWidget(
        testAppRouter(
          router: router,
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            divePlanSummariesProvider.overrideWith((ref) => gate.future),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('No saved plans yet'), findsNothing);

      gate.complete([
        DivePlanSummary(
          id: 'p1',
          name: 'Reef 30m',
          updatedAt: DateTime(2026, 7, 4),
          maxDepth: 30.0,
          runtimeSeconds: 45 * 60,
          ttsSeconds: 300,
          mode: PlanMode.oc,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('No saved plans yet'), findsNothing);
      // The hub lists the three most recent plans and the summary pane lists
      // the full set, so an overlapping plan legitimately renders in both.
      expect(
        find.descendant(
          of: find.byType(PlanningSummaryWidget),
          matching: find.text('Reef 30m'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tool opens beside the list, not over it', (tester) async {
      await pumpWide(tester);

      await tester.tap(find.text('Deco Calculator'));
      await tester.pumpAndSettle();

      // The calculator is in the pane...
      expect(find.text('Dive Parameters'), findsOneWidget);
      // ...and the hub list is still there beside it.
      expect(find.text('Surface Interval'), findsWidgets);
      expect(find.text('Dive Planner'), findsWidgets);
    });

    testWidgets('the chosen tool rides in the URL', (tester) async {
      final router = await pumpWide(tester);

      await tester.tap(find.text('Deco Calculator'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.queryParameters['tool'],
        'deco-calculator',
      );
    });

    // Every tool id in the hub must resolve to its own pane. The ids come
    // from the URL, so a typo in the switch would silently strand a
    // deep-linked tool on the summary instead.
    testWidgets('every tool id resolves to its own pane', (tester) async {
      const expected = {
        'deco-calculator': 'Deco Calculator',
        'gas-calculators': 'Gas Calculators',
        'weight-calculator': 'Weight Calculator',
        'surface-interval': 'Surface Interval',
        'no-fly': 'Flying after diving',
      };

      for (final entry in expected.entries) {
        final router = await pumpWide(tester);
        router.go('/planning?tool=${entry.key}');
        // Bounded pumps, not pumpAndSettle: the weight planner shows an
        // indefinite CircularProgressIndicator until its prediction resolves,
        // and an indefinite animation never lets pumpAndSettle return.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.descendant(
            of: find.byType(PlanningToolPane),
            matching: find.text(entry.value),
          ),
          findsOneWidget,
          reason: 'tool=${entry.key} did not open its pane',
        );
      }
    });

    testWidgets('an unknown tool id falls back to the summary', (tester) async {
      final router = await pumpWide(tester);
      router.go('/planning?tool=not-a-tool');
      await tester.pumpAndSettle();

      expect(find.byType(PlanningToolPane), findsNothing);
      expect(find.text('Select a tool to get started'), findsOneWidget);
    });

    testWidgets('the dive planner still takes the whole window', (
      tester,
    ) async {
      await pumpWide(tester);

      await tester.tap(find.text('Dive Planner'));
      await tester.pumpAndSettle();

      expect(find.text('dive planner page'), findsOneWidget);
      // The hub is covered, not split.
      expect(find.text('Deco Calculator'), findsNothing);
    });
  });

  test('deco calculator environment defaults to legacy standard water', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);

    final ndlAtSea = container.read(calcDecoStatusProvider).ndlSeconds;

    // Altitude shortens the NDL at the same depth/time/gas.
    container.read(calcAltitudeProvider.notifier).state = 2500.0;
    final ndlAtAltitude = container.read(calcDecoStatusProvider).ndlSeconds;
    expect(ndlAtAltitude, lessThan(ndlAtSea));
  });
}
