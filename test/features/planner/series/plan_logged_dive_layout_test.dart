import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_results.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_database.dart';
import 'series_fixtures.dart';

/// A logged dive picked in the series bar keeps the planner's layout (issue
/// #3565): when it was dived from a plan, that plan's segments and results
/// show read-only; its safety review's findings are its warnings.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  final morning = DateTime.utc(2026, 10, 25, 9);
  final dives = [
    loggedDive('d41', morning, number: 41),
    loggedDive('d42', morning.add(const Duration(hours: 3)), number: 42),
  ];

  LinkedPlanComparison linkedPlan() {
    final plan = divePlanFromState(seriesDiveState(id: 'p42'));
    final outcome = const PlanEngine().compute(plan);
    return LinkedPlanComparison(
      plan: plan,
      outcome: outcome,
      overlay: buildPlannedOverlay(plan, outcome: outcome),
    );
  }

  SafetyFinding finding(String diveId, {DateTime? dismissedAt}) =>
      SafetyFinding(
        id: 'f-$diveId-${dismissedAt == null}',
        diveId: diveId,
        ruleId: SafetyRuleId.rapidAscent,
        severity: SafetySeverity.caution,
        value: 15,
        engineVersion: 1,
        dismissedAt: dismissedAt,
        createdAt: morning,
      );

  Future<void> pumpLogged(
    WidgetTester tester, {
    required bool planned,
    Size size = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final linked = planned ? linkedPlan() : null;
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          divesProvider.overrideWith((ref) async => dives),
          diveProvider.overrideWith(
            (ref, id) async => dives.where((d) => d.id == id).firstOrNull,
          ),
          profileAnalysisProvider.overrideWith((ref, id) async => null),
          linkedPlanComparisonProvider.overrideWith(
            (ref, id) async => id == 'd42' ? linked : null,
          ),
          planResultRunnerProvider.overrideWithValue(
            const MainThreadPlanResultRunner(),
          ),
          safetyReviewEnabledProvider.overrideWithValue(true),
          safetyReviewDisabledRulesProvider.overrideWithValue(const {}),
          safetyReviewProvider.overrideWith(
            (ref, id) async => SafetyReview(
              diveId: id,
              engineVersion: 1,
              reviewedAt: morning,
              findings: [
                finding(id),
                // Dismissed, so not counted.
                finding(id, dismissedAt: morning),
              ],
            ),
          ),
        ],
        locale: const Locale('en'),
        child: const PlanCanvasPage(),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    final follow = await container.read(seriesFollowProvider('d42').future);
    container
        .read(planSeriesNotifierProvider.notifier)
        .followDive(follow!, surfaceInterval: const Duration(hours: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Logged dive #42'));
    await tester.pumpAndSettle();
  }

  testWidgets('a dive dived from a plan shows that plan read-only', (
    tester,
  ) async {
    await pumpLogged(tester, planned: true);

    // Its plan's segments, with nothing to edit.
    final segments = tester.widget<SegmentList>(find.byType(SegmentList));
    expect(segments.plan, isNotNull);
    expect(find.byTooltip('Add Segment'), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    // Its plan's schedule, gas and range table, as planned.
    expect(find.byKey(const Key('loggedDiveAsPlanned')), findsOneWidget);
    expect(find.text('As planned'), findsOneWidget);
    // And a way to Compare it with that plan.
    expect(find.byTooltip('Compare with its plan'), findsOneWidget);
  });

  testWidgets('a dive never planned has no plan to show', (tester) async {
    await pumpLogged(tester, planned: false);

    expect(find.byType(SegmentList), findsNothing);
    expect(find.byKey(const Key('loggedDiveNotPlanned')), findsOneWidget);
    expect(find.byKey(const Key('loggedDiveAsPlanned')), findsNothing);
    expect(find.byTooltip('Compare with its plan'), findsNothing);
  });

  testWidgets('its warnings are its safety review findings', (tester) async {
    await pumpLogged(tester, planned: false);

    final tile = find.byKey(const Key('loggedDiveWarningsTile'));
    expect(find.descendant(of: tile, matching: find.text('1')), findsOneWidget);
    expect(find.text('1 issue'), findsOneWidget);
    expect(find.byType(LoggedDiveResults), findsOneWidget);
  });

  testWidgets('Alt+Right from a logged dive shows Dive A; Alt+Left stays', (
    tester,
  ) async {
    await pumpLogged(tester, planned: false);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    Future<void> alt(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
    }

    await alt(LogicalKeyboardKey.arrowLeft);
    expect(container.read(viewedLoggedDiveIdProvider), 'd42');

    await alt(LogicalKeyboardKey.arrowRight);
    expect(container.read(viewedLoggedDiveIdProvider), isNull);
    expect(container.read(planSeriesNotifierProvider).selectedIndex, 0);
    expect(find.byType(LoggedDiveResults), findsNothing);
  });

  testWidgets('the carry card shows the interval the series settles on', (
    tester,
  ) async {
    await pumpLogged(tester, planned: false);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    final series = container.read(planSeriesNotifierProvider.notifier);
    container.read(viewedLoggedDiveIdProvider.notifier).state = null;
    // Dive A fixed at 15:00, then Dive B added and selected.
    series
      ..select(0)
      ..setSelectedStart(DateTime.utc(2026, 10, 25, 15))
      ..addDive();
    // Following #41 instead, which ended at 09:45, while Dive B is selected:
    // Dive A's fixed start now comes 5:15 after it.
    final follow41 = await container.read(seriesFollowProvider('d41').future);
    series.followDive(follow41!, surfaceInterval: const Duration(hours: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Logged dive #41'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('loggedDiveCarryCard')),
        matching: find.text('5:15'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('on a phone, a planned dive opens its Plan tab', (tester) async {
    await pumpLogged(tester, planned: true, size: const Size(420, 900));

    final tabs = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(tabs.segments.map((s) => s.enabled), [true, true, false, true]);

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<SegmentList>(find.byType(SegmentList)).plan,
      isNotNull,
    );

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('loggedDiveAsPlanned')), findsOneWidget);
  });
}
