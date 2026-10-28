import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_follow_prompt.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_logged_dive_view.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_series_navigator.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_database.dart';
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

/// Following logged dives from the planner (issue #3565, phase 4): the
/// logged dives in the series bar, the read-only logged-dive view, and the
/// one-tap Follow prompt.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Widget harness(List<Dive> dives) => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
      divesProvider.overrideWith((ref) async => dives),
      diveProvider.overrideWith(
        (ref, id) async => dives.where((d) => d.id == id).firstOrNull,
      ),
      // No profiles: the follow carries no tissues, and the logged view
      // shows its placeholder rather than the full chart.
      profileAnalysisProvider.overrideWith((ref, id) async => null),
    ],
    locale: const Locale('en'),
    child: const PlanCanvasPage(),
  );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlanCanvasPage)));

  Future<void> pumpPlan(
    WidgetTester tester,
    List<Dive> dives, {
    Size size = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness(dives));
    containerOf(tester)
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
  }

  Future<void> follow(WidgetTester tester, String diveId) async {
    final container = containerOf(tester);
    final follow = await container.read(seriesFollowProvider(diveId).future);
    container
        .read(planSeriesNotifierProvider.notifier)
        .followDive(follow!, surfaceInterval: const Duration(hours: 1));
    await tester.pumpAndSettle();
  }

  Finder inBar(Finder finder) =>
      find.descendant(of: find.byType(PlanSeriesNavigator), matching: finder);

  final morning = DateTime.utc(2026, 10, 25, 9);
  final dayDives = [
    loggedDive('d41', morning, number: 41),
    loggedDive(
      'd42',
      morning.add(const Duration(hours: 3)),
      number: 42,
      tanks: const [DiveTank(id: 'l1', endPressure: 90, gasMix: GasMix())],
    ),
  ];

  testWidgets('a followed dive and the ones before it lead the bar', (
    tester,
  ) async {
    await pumpPlan(tester, dayDives);
    await follow(tester, 'd42');

    expect(inBar(find.text('#41')), findsOneWidget);
    expect(inBar(find.text('#42')), findsOneWidget);
    expect(inBar(find.byIcon(Icons.scuba_diving)), findsNWidgets(2));
    // The real gap between the logged dives, then Dive A's interval.
    expect(inBar(find.text('2:15')), findsOneWidget);
    expect(inBar(find.text('1:00')), findsOneWidget);
    expect(
      tester.getCenter(inBar(find.text('#42'))).dx,
      lessThan(tester.getCenter(inBar(find.text('A'))).dx),
    );
    // The first dive now has an interval to set.
    final si = tester.widget<TextField>(
      find.byKey(const Key('surfaceIntervalField')),
    );
    expect(si.enabled, isTrue);
  });

  testWidgets('tapping a logged dive shows it read-only in place of the plan', (
    tester,
  ) async {
    await pumpPlan(tester, dayDives);
    await follow(tester, 'd42');

    await tester.tap(find.byTooltip('Logged dive #42'));
    await tester.pumpAndSettle();

    expect(find.byType(PlanLoggedDiveView), findsOneWidget);
    expect(find.byType(PlanTankList), findsNothing);
    expect(find.text('Open in dive log'), findsOneWidget);
    expect(find.text('Carried into Dive A'), findsOneWidget);
    // The air tank's logged end pressure is what carries on.
    expect(find.text('90 bar'), findsOneWidget);

    await tester.tap(find.byTooltip('Dive A'));
    await tester.pumpAndSettle();

    expect(find.byType(PlanLoggedDiveView), findsNothing);
    expect(find.byType(PlanTankList), findsOneWidget);
  });

  testWidgets('the logged view fits a phone', (tester) async {
    await pumpPlan(tester, dayDives, size: const Size(420, 900));
    await follow(tester, 'd42');

    await tester.tap(find.byTooltip('Logged dive #42'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(PlanLoggedDiveView), findsOneWidget);
    expect(find.text('Carried into Dive A'), findsOneWidget);
  });

  testWidgets('an earlier logged dive carries into the next logged one', (
    tester,
  ) async {
    await pumpPlan(tester, dayDives);
    await follow(tester, 'd42');

    await tester.tap(find.byTooltip('Logged dive #41'));
    await tester.pumpAndSettle();

    expect(find.text('Carried into #42'), findsOneWidget);
    expect(find.text('Stop following'), findsNothing);
  });

  testWidgets('Stop following drops the logged dives', (tester) async {
    await pumpPlan(tester, dayDives);
    await follow(tester, 'd42');
    await tester.tap(find.byTooltip('Logged dive #42'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stop following'));
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(planSeriesNotifierProvider).follow, isNull);
    expect(find.byType(PlanLoggedDiveView), findsNothing);
    expect(inBar(find.text('#42')), findsNothing);
  });

  group('the Follow prompt', () {
    List<Dive> recent() => [
      loggedDive(
        'd42',
        NoFlyService.wallClockNowUtc().subtract(const Duration(hours: 3)),
        number: 42,
      ),
    ];

    testWidgets('offers a dive that ended in the last 48 hours', (
      tester,
    ) async {
      await pumpPlan(tester, recent());

      expect(find.textContaining('Dive #42 ended'), findsOneWidget);
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      final follow = containerOf(
        tester,
      ).read(planSeriesNotifierProvider).follow;
      expect(follow?.followed.id, 'd42');
      expect(find.textContaining('Dive #42 ended'), findsNothing);
      // Planned for now: the interval is the time since the dive ended.
      expect(
        containerOf(tester).read(divePlanNotifierProvider).surfaceInterval,
        const Duration(hours: 2, minutes: 15),
      );
    });

    testWidgets('goes away when dismissed', (tester) async {
      await pumpPlan(tester, recent());

      await tester.tap(
        find.descendant(
          of: find.byType(PlanFollowPrompt),
          matching: find.byTooltip('Dismiss'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Dive #42 ended'), findsNothing);
      expect(
        containerOf(tester).read(planSeriesNotifierProvider).follow,
        isNull,
      );
    });

    testWidgets('is not offered for an older dive', (tester) async {
      await pumpPlan(tester, dayDives);

      expect(find.textContaining('ended'), findsNothing);
    });
  });
}
