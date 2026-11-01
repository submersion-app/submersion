import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
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
  Future<void> setPpO2MaxWorking(double value) async =>
      state = state.copyWith(ppO2MaxWorking: value);

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

  List<dynamic> followOverrides(
    List<Dive> dives,
    Future<ProfileAnalysis?> Function(Ref ref, String id) analysis, {
    _TestSettingsNotifier? settings,
    Future<void> Function(Ref ref)? beforeDive,
  }) => [
    settingsProvider.overrideWith((ref) => settings ?? _TestSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    divesProvider.overrideWith((ref) async => dives),
    diveProvider.overrideWith((ref, id) async {
      await beforeDive?.call(ref);
      return dives.where((d) => d.id == id).firstOrNull;
    }),
    profileAnalysisProvider.overrideWith(analysis),
  ];

  Widget harness(
    List<Dive> dives, {
    Future<ProfileAnalysis?> Function(Ref ref, String id)? analysis,
    Future<void> Function(Ref ref)? beforeDive,
  }) => testApp(
    // No profiles by default: the follow carries no tissues, and the logged
    // view shows its placeholder rather than the full chart.
    overrides: followOverrides(
      dives,
      analysis ?? (ref, id) async => null,
      beforeDive: beforeDive,
    ),
    locale: const Locale('en'),
    child: const PlanCanvasPage(),
  );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlanCanvasPage)));

  Future<void> pumpPlan(
    WidgetTester tester,
    List<Dive> dives, {
    Size size = const Size(1400, 900),
    Future<ProfileAnalysis?> Function(Ref ref, String id)? analysis,
    Future<void> Function(Ref ref)? beforeDive,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      harness(dives, analysis: analysis, beforeDive: beforeDive),
    );
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

  testWidgets('following scrolls the bar to the planned dive', (tester) async {
    final longDay = [
      for (var i = 0; i < 5; i++)
        loggedDive(
          'd${40 + i}',
          morning.add(Duration(hours: 2 * i)),
          number: 40 + i,
        ),
    ];
    await pumpPlan(tester, longDay, size: const Size(360, 900));
    await follow(tester, 'd44');

    final bar = tester.getRect(find.byType(PlanSeriesNavigator));
    final chip = tester.getRect(find.byTooltip('Dive A'));
    expect(chip.left, greaterThanOrEqualTo(bar.left));
    expect(chip.right, lessThanOrEqualTo(bar.right));
    // The oldest logged dive has scrolled out of view to make room.
    expect(
      tester.getRect(inBar(find.text('#40'))).right,
      lessThan(bar.left + 16),
    );
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

  testWidgets('a named logged dive goes by its name', (tester) async {
    await pumpPlan(tester, [
      loggedDive('d41', morning, number: 41),
      loggedDive(
        'd42',
        morning.add(const Duration(hours: 3)),
        number: 42,
        name: 'Blue Hole',
      ),
    ]);
    await follow(tester, 'd42');

    expect(inBar(find.text('Blue Hole')), findsOneWidget);
    expect(inBar(find.text('#42')), findsNothing);
    expect(inBar(find.text('#41')), findsOneWidget);

    await tester.tap(find.byTooltip('Logged dive Blue Hole'));
    await tester.pumpAndSettle();

    // The number the label leaves out stays beside the date.
    expect(find.textContaining('#42 · '), findsOneWidget);
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

  testWidgets('the logged dive chart starts clean, apart from the dive log', (
    tester,
  ) async {
    await pumpPlan(tester, [
      loggedDive('d41', morning, number: 41),
      Dive(
        id: 'd42',
        diveNumber: 42,
        dateTime: morning.add(const Duration(hours: 3)),
        entryTime: morning.add(const Duration(hours: 3)),
        runtime: const Duration(minutes: 10),
        profile: [
          for (var t = 0; t <= 600; t += 30)
            DiveProfilePoint(
              timestamp: t,
              depth: t < 60 || t > 540 ? t / 30 : 18,
              temperature: 22,
            ),
        ],
      ),
    ]);
    await follow(tester, 'd42');
    await tester.tap(find.byTooltip('Logged dive #42'));
    await tester.pumpAndSettle();

    final chart = find.byType(DiveProfileChartHost);
    expect(chart, findsOneWidget);
    final legend = ProviderScope.containerOf(
      tester.element(chart),
    ).read(profileLegendProvider);
    expect(legend.showNdl, isTrue);
    expect(legend.showDecoStops, isTrue);
    expect(legend.showCeiling, isTrue);
    expect(legend.showTemperature, isFalse);
    expect(legend.showEvents, isFalse);
    expect(legend.showMaxDepthMarker, isFalse);
    // The dive log's own legend is left as the diver set it.
    expect(
      containerOf(tester).read(profileLegendProvider).showTemperature,
      isTrue,
    );
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

  testWidgets('a logged dive keeps its CNS and OTU while its analysis '
      'reloads', (tester) async {
    // A settings or dive log change reloads the analysis. Held open so the
    // reload spans frames.
    final reload = StateProvider<int>((ref) => 0);
    Completer<void>? gate;
    await pumpPlan(
      tester,
      dayDives,
      analysis: (ref, id) async {
        if (ref.watch(reload) > 0) await gate!.future;
        return ProfileAnalysis.empty().copyWith(
          o2Exposure: const O2Exposure(cnsEnd: 12, otu: 34),
        );
      },
    );
    await follow(tester, 'd42');
    await tester.tap(find.byTooltip('Logged dive #42'));
    await tester.pumpAndSettle();
    expect(find.text('12%'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);

    gate = Completer<void>();
    containerOf(tester).read(reload.notifier).state++;
    await tester.pump();
    await tester.pump();

    expect(find.text('12%'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a logged dive stays on screen while it reloads', (tester) async {
    final reload = StateProvider<int>((ref) => 0);
    Completer<void>? gate;
    await pumpPlan(
      tester,
      dayDives,
      beforeDive: (ref) async {
        if (ref.watch(reload) > 0) await gate!.future;
      },
    );
    await follow(tester, 'd42');
    await tester.tap(find.byTooltip('Logged dive #42'));
    await tester.pumpAndSettle();

    gate = Completer<void>();
    containerOf(tester).read(reload.notifier).state++;
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('following analyses only the dives whose OTU can still count', (
    tester,
  ) async {
    final analysed = <String>[];
    final last = DateTime.utc(2026, 10, 25, 12);
    await pumpPlan(
      tester,
      [
        loggedDive('old', last.subtract(const Duration(hours: 30)), number: 1),
        loggedDive('near', last.subtract(const Duration(hours: 6)), number: 2),
        loggedDive('last', last, number: 3),
      ],
      analysis: (ref, id) async {
        analysed.add(id);
        return null;
      },
    );

    final follow = await containerOf(
      tester,
    ).read(seriesFollowProvider('last').future);

    expect(follow!.loggedDives.map((d) => d.id), ['old', 'near', 'last']);
    expect(analysed, ['near', 'last']);
  });

  testWidgets('a follow still lands when its caller has gone', (tester) async {
    final analysis = Completer<ProfileAnalysis?>();
    final showCaller = ValueNotifier(true);
    addTearDown(showCaller.dispose);
    late WidgetRef callerRef;
    await tester.pumpWidget(
      testApp(
        overrides: followOverrides(dayDives, (ref, id) => analysis.future),
        locale: const Locale('en'),
        child: ValueListenableBuilder<bool>(
          valueListenable: showCaller,
          builder: (_, show, _) => show
              ? Consumer(
                  builder: (_, ref, _) {
                    callerRef = ref;
                    return const SizedBox.shrink();
                  },
                )
              : const SizedBox.shrink(),
        ),
      ),
    );

    final done = followLoggedDive(callerRef, 'd41');
    showCaller.value = false;
    await tester.pump();
    analysis.complete(null);

    expect(await done, isNotNull);
  });

  testWidgets('a follow finishes when its load is invalidated part way', (
    tester,
  ) async {
    // Issue #3807: read without a listener, an invalidated load is cancelled
    // and never completes, leaving the Follow sheet spinning.
    final analysis = Completer<ProfileAnalysis?>();
    late WidgetRef callerRef;
    await tester.pumpWidget(
      testApp(
        overrides: followOverrides(dayDives, (ref, id) => analysis.future),
        locale: const Locale('en'),
        child: Consumer(
          builder: (_, ref, _) {
            callerRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    var finished = false;
    unawaited(followLoggedDive(callerRef, 'd41').then((_) => finished = true));
    await tester.pump();
    callerRef.invalidate(seriesFollowProvider('d41'));
    await tester.pump();
    analysis.complete(null);
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });

  testWidgets('a settings change while the planner is away is picked up on '
      'its return', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final showPlanner = ValueNotifier(true);
    addTearDown(showPlanner.dispose);
    final settings = _TestSettingsNotifier();
    await tester.pumpWidget(
      testApp(
        overrides: followOverrides(
          dayDives,
          (ref, id) async => null,
          settings: settings,
        ),
        locale: const Locale('en'),
        child: ValueListenableBuilder<bool>(
          valueListenable: showPlanner,
          builder: (_, show, _) =>
              show ? const PlanCanvasPage() : const SizedBox.shrink(),
        ),
      ),
    );
    final container = containerOf(tester);
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
    container.read(planSeriesNotifierProvider.notifier).addDive();
    await tester.pumpAndSettle();

    showPlanner.value = false;
    await tester.pumpAndSettle();
    await settings.setPpO2MaxWorking(1.3);
    await tester.pump();
    showPlanner.value = true;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(planSeriesNotifierProvider).dives, hasLength(2));
  });

  group('the surface interval field', () {
    Finder field() => find.byKey(const Key('surfaceIntervalField'));

    Future<void> pumpTwoFollowing(WidgetTester tester) async {
      await pumpPlan(tester, dayDives);
      await follow(tester, 'd42');
      containerOf(tester).read(planSeriesNotifierProvider.notifier).addDive();
      await tester.pumpAndSettle();
    }

    testWidgets('text not committed stays with the dive it was typed for', (
      tester,
    ) async {
      await pumpTwoFollowing(tester);
      await tester.enterText(field(), '2:30');
      await tester.pump();

      containerOf(tester).read(planSeriesNotifierProvider.notifier).select(0);
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final series = containerOf(tester).read(planSeriesNotifierProvider);
      expect(series.dives[0].state.surfaceInterval, const Duration(hours: 1));
      expect(series.dives[1].state.surfaceInterval, const Duration(hours: 1));
      expect(tester.widget<TextField>(field()).controller?.text, '1:00');
    });

    testWidgets('a stepper starts from what was typed', (tester) async {
      await pumpTwoFollowing(tester);
      await tester.enterText(field(), '2:00');
      await tester.pump();

      await tester.tap(find.byTooltip('15 minutes more'));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(divePlanNotifierProvider).surfaceInterval,
        const Duration(hours: 2, minutes: 15),
      );
    });
  });

  testWidgets('a followed plan offers neither Save nor Convert to Dive', (
    tester,
  ) async {
    await pumpPlan(tester, dayDives);
    await follow(tester, 'd42');

    final save = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.save),
        matching: find.byType(IconButton),
      ),
    );
    expect(save.onPressed, isNull);
    expect(save.tooltip, "A series of dives can't be saved yet");

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    final convert = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text('Convert to Dive'),
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(convert.enabled, isFalse);
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

    testWidgets('names a named dive', (tester) async {
      await pumpPlan(tester, [
        loggedDive(
          'd42',
          NoFlyService.wallClockNowUtc().subtract(const Duration(hours: 3)),
          number: 42,
          name: 'Blue Hole',
        ),
      ]);

      expect(find.textContaining('Blue Hole ended'), findsOneWidget);
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

    testWidgets('is not offered on a later dive of a replan', (tester) async {
      await pumpPlan(tester, recent());
      final container = containerOf(tester);
      final editor = container.read(divePlanNotifierProvider.notifier);
      editor.loadPlan(
        container
            .read(divePlanNotifierProvider)
            .copyWith(sourceDiveId: 'replanned'),
      );
      container.read(planSeriesNotifierProvider.notifier).addDive();
      await tester.pumpAndSettle();

      expect(find.textContaining('ended'), findsNothing);
    });

    testWidgets('skips a dive stamped in the future', (tester) async {
      final now = NoFlyService.wallClockNowUtc();
      await pumpPlan(tester, [
        ...recent(),
        loggedDive('d43', now.add(const Duration(days: 2)), number: 43),
      ]);

      expect(find.textContaining('Dive #42 ended'), findsOneWidget);
    });
  });
}
