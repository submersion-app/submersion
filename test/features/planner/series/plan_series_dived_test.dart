import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_chip.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/panes/plan_editor_pane.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_update.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_results.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_runtime_table.dart';
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

/// Dives of a series that have been dived (issue #3565).
void main() {
  final nine = DateTime.utc(2026, 10, 27, 9);

  group('from the log', () {
    late ProviderContainer c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await setUpTestDatabase();
      final prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          profileAnalysisProvider.overrideWith((ref, id) async => null),
        ],
      );
      addTearDown(c.dispose);
      c
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 18, bottomTimeMinutes: 20);
      c.read(planSeriesNotifierProvider);
    });

    tearDown(tearDownTestDatabase);

    PlanSeriesNotifier series() => c.read(planSeriesNotifierProvider.notifier);

    /// Dives A and B written to the log as planned; returns A's entry.
    Future<String> twoDivesInTheLog() async {
      series().setSelectedStart(nine);
      series().addDive();
      series().fillAllTanks();
      await updatePlannedDives(c);
      return c.read(planSeriesNotifierProvider).dives[0].state.linkedDiveId!;
    }

    SeriesFollow divedAt(String id, DateTime start) => SeriesFollow(
      loggedDives: [
        seriesLoggedDive(id, start.add(const Duration(minutes: 45))),
      ],
    );

    test(
      'a planned entry is not dived, and nothing is read with no links',
      () async {
        expect(await c.read(seriesActualsProvider.future), isEmpty);

        await twoDivesInTheLog();

        expect(await c.read(seriesActualsProvider.future), isEmpty);
      },
    );

    test('marking the entry as logged makes the dive dived', () async {
      final first = await twoDivesInTheLog();
      final planId = c.read(planSeriesNotifierProvider).dives[0].state.id;

      await c.read(diveRepositoryProvider).convertPlanToActualDive(first);
      c.invalidate(seriesActualsProvider);
      c.invalidate(divesProvider);
      final actuals = await c.read(seriesActualsProvider.future);

      expect(actuals.keys, [planId]);
      expect(actuals[planId]?.followed.id, first);
      expect(actuals[planId]?.followed.diveNumber, isNotNull);
    });

    test('a dived entry with no analysis leaves CNS and OTU unknown', () async {
      final first = await twoDivesInTheLog();
      final planId = c.read(planSeriesNotifierProvider).dives[0].state.id;

      await c.read(diveRepositoryProvider).convertPlanToActualDive(first);
      c.invalidate(seriesActualsProvider);
      c.invalidate(divesProvider);
      final actual = (await c.read(seriesActualsProvider.future))[planId];

      // Unknown, not zero, so the next dive falls back to the plan.
      expect(actual?.endCns, isNull);
      expect(actual?.followed.otu, isNull);
    });

    test('an undone download takes the dive back to its plan', () async {
      await twoDivesInTheLog();
      final dive = c.read(planSeriesNotifierProvider).dives[0];
      series().setActuals({dive.state.id: divedAt('x', nine)});
      expect(c.read(planSeriesNotifierProvider).dives[0].actual, isNotNull);

      series().setActuals(const {});

      expect(c.read(planSeriesNotifierProvider).dives[0].actual, isNull);
    });

    test('the same actuals change nothing', () async {
      await twoDivesInTheLog();
      final before = c.read(planSeriesNotifierProvider);

      series().setActuals(const {});

      expect(identical(c.read(planSeriesNotifierProvider), before), isTrue);
    });

    test('a dived dive stays dived across a save', () async {
      final first = await twoDivesInTheLog();
      final state = c.read(planSeriesNotifierProvider).dives[0].state;
      await c.read(diveRepositoryProvider).convertPlanToActualDive(first);
      final later = nine.add(const Duration(hours: 2));
      series().setActuals({state.id: divedAt(first, later)});

      await saveCurrentSeries(c);

      // Its plan keeps the planned start; the chain has the real one.
      final stored = await c.read(divePlanRepositoryProvider).getPlan(state.id);
      expect(stored?.startDateTime, nine);
      expect(c.read(planSeriesNotifierProvider).dives[0].actual, isNotNull);
      expect(c.read(planSeriesResultsProvider)[0].state.startDateTime, later);
    });

    test('a selected dived dive keeps its plan in the editor', () async {
      await twoDivesInTheLog();
      final bStart = c.read(divePlanNotifierProvider).startDateTime;
      series().select(0);
      final a = c.read(planSeriesNotifierProvider).dives[0].state;
      final b = c.read(planSeriesNotifierProvider).dives[1].state;
      final later = nine.add(const Duration(hours: 2));

      series().setActuals({a.id: divedAt('x', later)});

      // The editor and the series hold the plan, not what happened.
      expect(c.read(divePlanNotifierProvider).startDateTime, nine);
      final dived = c.read(planSeriesNotifierProvider).dives[0].state;
      expect(dived.startDateTime, nine);
      expect(dived.surfaceInterval, a.surfaceInterval);

      // B dived too: its plan view carries from A's plan, not A's actual.
      series().select(1);
      series().setActuals({
        a.id: divedAt('x', later),
        b.id: divedAt('y', later.add(const Duration(hours: 3))),
      });
      expect(c.read(divePlanNotifierProvider).startDateTime, bStart);
      expect(
        c.read(planSeriesNotifierProvider).dives[1].state.startDateTime,
        bStart,
      );

      // Once the actuals go, the plans are as they were.
      series().setActuals(const {});
      final after = c.read(planSeriesNotifierProvider).dives;
      expect(after[0].state.surfaceInterval, a.surfaceInterval);
      expect(after[1].state.startDateTime, bStart);
    });

    test('a single dived plan with no start keeps none', () async {
      final editor = c.read(divePlanNotifierProvider.notifier);
      editor.newPlan();
      editor.addSimplePlan(maxDepth: 18, bottomTimeMinutes: 20);
      await editor.save();
      final id = c.read(divePlanNotifierProvider).id;

      series().setActuals({id: divedAt('y', nine)});

      final state = c.read(divePlanNotifierProvider);
      expect(state.startDateTime, isNull);
      expect(state.surfaceInterval, isNull);
      expect(
        c.read(planSeriesNotifierProvider).dives.single.state.startDateTime,
        isNull,
      );
    });

    test('being dived is not an edit, on a series or one plan', () async {
      await twoDivesInTheLog();
      series().select(0);
      final dives = c.read(planSeriesNotifierProvider).dives;
      expect(c.read(planSeriesDirtyProvider), isFalse);

      series().setActuals({dives[0].state.id: divedAt('x', nine)});
      expect(c.read(planSeriesDirtyProvider), isFalse);

      // One saved plan, dived.
      final editor = c.read(divePlanNotifierProvider.notifier);
      editor.newPlan();
      editor.addSimplePlan(maxDepth: 18, bottomTimeMinutes: 20);
      series().setSelectedStart(nine);
      await editor.save();
      final id = c.read(divePlanNotifierProvider).id;
      expect(c.read(planSeriesDirtyProvider), isFalse);

      series().setActuals({
        id: divedAt('y', nine.add(const Duration(hours: 1))),
      });
      expect(c.read(planSeriesDirtyProvider), isFalse);
    });

    test('a saved series opens with its dived dive dived at once', () async {
      final first = await twoDivesInTheLog();
      final a = c.read(planSeriesNotifierProvider).dives[0].state.id;
      await c.read(diveRepositoryProvider).convertPlanToActualDive(first);
      c.invalidate(divesProvider);
      c.read(divePlanNotifierProvider.notifier).newPlan();
      expect(c.read(planSeriesNotifierProvider).dives.single.actual, isNull);

      await openSavedPlan(c, a);

      // Nothing waits on the planner's own read of the log.
      final opened = c.read(planSeriesNotifierProvider);
      expect(opened.selected.state.id, a);
      expect(opened.selected.actual?.followed.id, first);
      expect(c.read(viewedLoggedDiveProvider)?.id, first);
    });

    test('a single saved plan opens dived at once too', () async {
      final editor = c.read(divePlanNotifierProvider.notifier);
      series().setSelectedStart(nine);
      await editor.save();
      final id = c.read(divePlanNotifierProvider).id;
      final dive = await c
          .read(diveRepositoryProvider)
          .createDive(Dive(id: '', diveNumber: 9, dateTime: nine));
      await c.read(divePlanRepositoryProvider).linkPlanToDive(id, dive.id);
      c.invalidate(divesProvider);
      editor.newPlan();

      await openSavedPlan(c, id);

      expect(c.read(planSeriesNotifierProvider).selected.state.id, id);
      expect(c.read(viewedLoggedDiveProvider)?.id, dive.id);
    });

    test('Update leaves a dived dive out of its checks', () async {
      await twoDivesInTheLog();
      final dives = c.read(planSeriesNotifierProvider).dives;
      series().setActuals({dives[0].state.id: divedAt('x', nine)});

      final result = await updatePlannedDives(c);

      expect(result.valid, isTrue);
    });

    test(
      'the selected dive, dived, is shown in the planner\'s place',
      () async {
        await twoDivesInTheLog();
        final dives = c.read(planSeriesNotifierProvider).dives;
        series().select(0);
        series().setActuals({dives[0].state.id: divedAt('x', nine)});

        expect(c.read(viewedLoggedDiveProvider)?.id, 'x');

        c.read(showPlanOfDivedProvider.notifier).state = true;
        expect(c.read(viewedLoggedDiveProvider), isNull);

        series().select(1);
        expect(c.read(viewedLoggedDiveProvider), isNull);
      },
    );

    test('a later dive plan in the log carries the dive before', () async {
      await twoDivesInTheLog();
      final b = c.read(planSeriesNotifierProvider).dives[1].state;
      final stored = (await c.read(divePlanRepositoryProvider).getPlan(b.id))!;

      final comparison = await c.read(
        linkedPlanComparisonProvider(b.linkedDiveId!).future,
      );
      final fresh = const PlanEngine().compute(stored);

      expect(
        comparison!.outcome.surfacedTissue.compartments,
        isNot(fresh.surfacedTissue.compartments),
      );
      expect(
        comparison.outcome.surfacedTissue.compartments,
        c
            .read(planSeriesResultsProvider)[1]
            .outcome
            .surfacedTissue
            .compartments,
      );
    });

    test('the first dive of a series following nothing starts fresh', () async {
      await twoDivesInTheLog();
      final a = c.read(planSeriesNotifierProvider).dives[0].state;
      final stored = (await c.read(divePlanRepositoryProvider).getPlan(a.id))!;

      final comparison = await c.read(
        linkedPlanComparisonProvider(a.linkedDiveId!).future,
      );

      expect(
        comparison!.outcome.surfacedTissue.compartments,
        const PlanEngine().compute(stored).surfacedTissue.compartments,
      );
    });
  });

  group('on the planner', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    final logged = Dive(
      id: 'logged',
      diveNumber: 214,
      dateTime: nine,
      runtime: const Duration(minutes: 40),
      maxDepth: 25,
    );

    Future<ProviderContainer> pumpDived(
      WidgetTester tester, {
      Size size = const Size(1400, 1000),
      bool series = true,
      List<dynamic> overrides = const [],
      void Function(ProviderContainer c)? prepare,
    }) async {
      tester.view.physicalSize = size;
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
            divesProvider.overrideWith((ref) async => [logged]),
            diveProvider.overrideWith((ref, id) async => logged),
            profileAnalysisProvider.overrideWith((ref, id) async => null),
            linkedPlanComparisonProvider.overrideWith((ref, id) async => null),
            planResultRunnerProvider.overrideWithValue(
              const MainThreadPlanResultRunner(),
            ),
            ...overrides,
          ],
          locale: const Locale('en'),
          child: const PlanCanvasPage(),
        ),
      );
      final c = ProviderScope.containerOf(
        tester.element(find.byType(PlanCanvasPage)),
      );
      c
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 18, bottomTimeMinutes: 20);
      final notifier = c.read(planSeriesNotifierProvider.notifier);
      if (series) {
        notifier.addDive();
        notifier.select(0);
      }
      prepare?.call(c);
      await tester.pumpAndSettle();
      notifier.setActuals({
        c.read(planSeriesNotifierProvider).dives[0].state.id: SeriesFollow(
          loggedDives: [
            seriesLoggedDive(
              'logged',
              nine.add(const Duration(minutes: 40)),
              minutes: 40,
              number: 214,
            ),
          ],
        ),
      });
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('its chip goes by the real dive, and cannot be removed', (
      tester,
    ) async {
      await pumpDived(tester);

      expect(find.byTooltip('Logged dive #214'), findsOneWidget);
      expect(find.byTooltip('Remove Dive A'), findsNothing);
    });

    testWidgets('it opens on what happened, with the toggle to its plan', (
      tester,
    ) async {
      await pumpDived(tester);

      expect(find.byType(LoggedDiveResults), findsOneWidget);
      expect(find.byKey(const Key('planActualToggle')), findsOneWidget);
      // Its details, read-only with a way to the dive, and no segments.
      expect(find.byKey(const Key('loggedDiveName')), findsOneWidget);
      expect(find.byTooltip('Open in dive log'), findsOneWidget);
      expect(find.byType(SegmentList), findsNothing);
    });

    testWidgets('a reread of the log shows no plan before it is done', (
      tester,
    ) async {
      // The log's answer for any link never comes, as on a slow first read.
      final c = await pumpDived(
        tester,
        overrides: [
          seriesActualsProvider.overrideWith((ref) {
            final linked = ref.watch(
              planSeriesNotifierProvider.select(
                (s) => s.dives.any((d) => d.state.linkedDiveId != null),
              ),
            );
            return linked
                ? Completer<Map<String, SeriesFollow>>().future
                : Future.value(const <String, SeriesFollow>{});
          }),
        ],
      );
      final b = c.read(planSeriesNotifierProvider).dives[1].state.id;

      // A new link reads the log again; until then the old answer stands.
      c.read(planSeriesNotifierProvider.notifier).adoptLinks({b: 'other'});
      await tester.pump();
      await tester.pump();

      expect(c.read(planSeriesNotifierProvider).dives[0].actual, isNotNull);
      expect(find.byType(LoggedDiveResults), findsOneWidget);
    });

    testWidgets('the toggle shows the plan, read-only, and back', (
      tester,
    ) async {
      // A start, a site-less dive and two tanks: each would offer an edit.
      await pumpDived(
        tester,
        prepare: (c) {
          c.read(planSeriesNotifierProvider.notifier).setSelectedStart(nine);
          c
              .read(divePlanNotifierProvider.notifier)
              .addTank(
                const DiveTank(
                  id: 'stage',
                  volume: 7,
                  startPressure: 200,
                  gasMix: ean50,
                ),
              );
        },
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('planActualToggle')),
          matching: find.text('Plan'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoggedDiveResults), findsNothing);
      expect(find.textContaining('As planned. Dived as'), findsNothing);
      // Its details read, with a way to the dive; its tanks offer nothing.
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('diveNameField')))
            .readOnly,
        isTrue,
      );
      expect(find.byKey(const Key('planDetailsOpenInLog')), findsOneWidget);
      expect(find.byTooltip('Add Tank'), findsNothing);
      expect(find.text('Saved tanks'), findsNothing);
      // Nothing that looks like it can still be changed.
      expect(find.byTooltip('Clear the start time'), findsNothing);
      expect(find.byTooltip('15 minutes less'), findsNothing);
      expect(find.byTooltip('15 minutes more'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('diveSiteField')),
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
        findsNothing,
      );
      final chips = tester.widgetList<PlanTankChip>(find.byType(PlanTankChip));
      expect(chips, hasLength(2));
      expect(chips.every((chip) => chip.onDelete == null), isTrue);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('planActualToggle')),
          matching: find.text('Actual'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoggedDiveResults), findsOneWidget);
    });

    testWidgets('its plan'
        's stop table and name cannot be edited', (tester) async {
      final c = await pumpDived(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('planActualToggle')),
          matching: find.text('Plan'),
        ),
      );
      await tester.pumpAndSettle();

      final tables = tester.widgetList<PlanRuntimeTable>(
        find.byType(PlanRuntimeTable),
      );
      expect(tables, isNotEmpty);
      expect(tables.every((table) => !table.editable), isTrue);

      // The app bar's name offers no rename.
      final name = c.read(divePlanNotifierProvider).name;
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsNothing,
      );
      await tester.tap(
        find.descendant(of: find.byType(AppBar), matching: find.text(name)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('a dive still planned shows the planner, and can go', (
      tester,
    ) async {
      final c = await pumpDived(tester);

      c.read(planSeriesNotifierProvider.notifier).select(1);
      await tester.pumpAndSettle();

      expect(find.byType(LoggedDiveResults), findsNothing);
      expect(find.byKey(const Key('planActualToggle')), findsNothing);
      expect(find.byTooltip('Remove Dive B'), findsOneWidget);
      // A plan still open has its tanks' controls, and no link to a dive.
      expect(find.byTooltip('Add Tank'), findsOneWidget);
      expect(find.byKey(const Key('planDetailsOpenInLog')), findsNothing);
    });

    testWidgets('on a phone too', (tester) async {
      await pumpDived(tester, size: const Size(420, 900));

      expect(find.byTooltip('Logged dive #214'), findsOneWidget);
      expect(find.byKey(const Key('planActualToggle')), findsOneWidget);
    });

    Future<void> showPlan(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('planActualToggle')),
          matching: find.text('Plan'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the toggle buttons stay put between Actual and Plan', (
      tester,
    ) async {
      await pumpDived(tester);
      final actual = find.descendant(
        of: find.byKey(const Key('planActualToggle')),
        matching: find.text('Actual'),
      );
      final before = tester.getTopLeft(actual);

      await showPlan(tester);

      expect(tester.getTopLeft(actual), before);
    });

    testWidgets('its plan scrolls, and Setup opens to read but not edit', (
      tester,
    ) async {
      await pumpDived(tester);
      await showPlan(tester);

      final pane = find.byType(PlanEditorPane);
      final scrollable = find
          .descendant(of: pane, matching: find.byType(Scrollable))
          .first;
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0),
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('planSetup_deco')),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.byKey(const ValueKey('planSetup_deco')));
      await tester.pumpAndSettle();
      final body = tester.widget<IgnorePointer>(
        find.byKey(const ValueKey('planSetupBody_deco')),
      );
      expect(body.ignoring, isTrue);
    });

    testWidgets('a single plan, dived, offers no new planned dive', (
      tester,
    ) async {
      await pumpDived(tester, series: false);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Create planned dive'), findsNothing);
      expect(find.text('Update planned dive'), findsNothing);
    });
  });
}
