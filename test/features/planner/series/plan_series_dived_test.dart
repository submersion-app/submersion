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
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_update.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_logged_dive_view.dart';
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

  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  group('from the log', () {
    late ProviderContainer c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
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

    PlanSeriesNotifier series() => c.read(planSeriesNotifierProvider.notifier);

    Future<String> twoDivesInTheLog() async {
      series().setSelectedStart(nine);
      series().addDive();
      series().fillAllTanks();
      await updatePlannedDives(c);
      return c.read(planSeriesNotifierProvider).dives[0].state.linkedDiveId!;
    }

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

    test('an undone download takes the dive back to its plan', () async {
      await twoDivesInTheLog();
      final dive = c.read(planSeriesNotifierProvider).dives[0];
      series().setActuals({
        dive.state.id: SeriesFollow(
          loggedDives: [seriesLoggedDive('x', DateTime(2026, 10, 27, 10))],
        ),
      });
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

    test(
      'saving keeps a dived dive\'s original plan, and its actual',
      () async {
        final first = await twoDivesInTheLog();
        final state = c.read(planSeriesNotifierProvider).dives[0].state;
        final repository = c.read(diveRepositoryProvider);
        await repository.convertPlanToActualDive(first);
        final differently = nine.add(const Duration(hours: 2));
        series().setActuals({
          state.id: SeriesFollow(
            loggedDives: [seriesLoggedDive(first, differently)],
          ),
        });

        await saveCurrentSeries(c);

        final stored = await c
            .read(divePlanRepositoryProvider)
            .getPlan(state.id);
        expect(stored?.startDateTime, nine);
        expect(c.read(planSeriesNotifierProvider).dives[0].actual, isNotNull);
      },
    );

    test('Update leaves a dived dive out of its checks', () async {
      await twoDivesInTheLog();
      final dives = c.read(planSeriesNotifierProvider).dives;
      series().setActuals({
        dives[0].state.id: SeriesFollow(
          loggedDives: [seriesLoggedDive('x', DateTime(2026, 10, 27, 10))],
        ),
      });

      final result = await updatePlannedDives(c);

      expect(result.valid, isTrue);
    });

    test(
      'a later dive overlay on the log chart carries the dive before',
      () async {
        // Deep enough that residual load lengthens the second dive's stops.
        c
            .read(divePlanNotifierProvider.notifier)
            .addSimplePlan(maxDepth: 40, bottomTimeMinutes: 30);
        series().addDive();
        await c
            .read(diveRepositoryProvider)
            .createDive(Dive(id: 'entry', dateTime: nine, isPlanned: true));
        series().setLinkedDives({1: 'entry'});
        await saveCurrentSeries(c);
        final b = c.read(planSeriesNotifierProvider).dives[1].state;
        final stored = (await c
            .read(divePlanRepositoryProvider)
            .getPlan(b.id))!;
        expect(stored.seriesId, isNotNull);

        final overlay = await c.read(
          plannedProfileOverlayProvider('entry').future,
        );
        final alone = buildPlannedOverlay(stored);

        expect(
          overlay!.points.last.timestamp,
          greaterThan(alone.points.last.timestamp),
        );
      },
    );
  });

  group('on the planner', () {
    Future<ProviderContainer> pumpDived(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final logged = Dive(
        id: 'logged',
        diveNumber: 214,
        dateTime: nine,
        runtime: const Duration(minutes: 40),
        maxDepth: 25,
      );
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            diveProvider.overrideWith((ref, id) async => logged),
            profileAnalysisProvider.overrideWith((ref, id) async => null),
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
      notifier.addDive();
      notifier.select(0);
      await tester.pumpAndSettle();
      notifier.setActuals({
        c.read(planSeriesNotifierProvider).dives[0].state.id: SeriesFollow(
          loggedDives: [
            seriesLoggedDive(
              'logged',
              DateTime(2026, 10, 27, 10),
              number: 214,
            ).copyWith(start: nine),
          ],
        ),
      });
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('its chip goes by the real dive', (tester) async {
      await pumpDived(tester);

      expect(find.text('#214'), findsWidgets);
      expect(find.byTooltip('Dive A'), findsNothing);
    });

    testWidgets('it opens on what happened, with the plan to compare', (
      tester,
    ) async {
      await pumpDived(tester);

      expect(find.byType(PlanLoggedDiveView), findsOneWidget);
      expect(find.byKey(const Key('divedComparison')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('divedComparison')),
          matching: find.text('Plan'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('planActualToggle')), findsOneWidget);
    });

    testWidgets('the toggle shows the plan, read-only, and back', (
      tester,
    ) async {
      await pumpDived(tester);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('planActualToggle')),
          matching: find.text('Plan'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlanLoggedDiveView), findsNothing);
      expect(find.textContaining('As planned. Dived as #214'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('diveNameField')),
          matching: find.byWidgetPredicate(
            (w) => w is IgnorePointer && w.ignoring,
          ),
        ),
        findsWidgets,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('planActualToggle')),
          matching: find.text('Actual'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlanLoggedDiveView), findsOneWidget);
    });

    testWidgets('moving to a dive still planned shows the planner', (
      tester,
    ) async {
      final c = await pumpDived(tester);

      c.read(planSeriesNotifierProvider.notifier).select(1);
      await tester.pumpAndSettle();

      expect(find.byType(PlanLoggedDiveView), findsNothing);
      expect(find.byKey(const Key('planActualToggle')), findsNothing);
    });
  });
}
