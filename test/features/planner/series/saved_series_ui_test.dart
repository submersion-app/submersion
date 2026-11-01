import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_list.dart';
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

/// The saved list and the prompt on leaving a series (issue #3565).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  List<Override> overrides() => [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
  ];

  testWidgets('the list shows a series as one row with a line per dive', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await DivePlanSeriesRepository().saveSeries(
        StoredSeries(
          id: 's1',
          name: 'Reef day',
          dives: [
            StoredSeriesDive(
              plan: divePlanFromState(seriesDiveState(id: 'a')),
              name: 'Wreck',
              summaryMaxDepth: 30,
              summaryRuntimeSeconds: 2400,
            ),
            StoredSeriesDive(
              plan: divePlanFromState(seriesDiveState(id: 'b')),
              summaryMaxDepth: 18,
              summaryRuntimeSeconds: 3000,
            ),
          ],
        ),
      );
      await DivePlanRepository().savePlan(
        divePlanFromState(
          seriesDiveState(id: 'solo').copyWith(name: 'Solo plan'),
        ),
      );
    });

    await tester.pumpWidget(
      testApp(
        overrides: overrides(),
        locale: const Locale('en'),
        child: const SingleChildScrollView(child: SavedPlansList()),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text('Reef day'), findsOneWidget);
    expect(find.textContaining('2 dives'), findsOneWidget);
    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Solo plan'), findsOneWidget);
    expect(find.byKey(const ValueKey('savedSeriesDive_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('savedSeriesDive_solo')), findsNothing);
  });

  testWidgets(
    'a dive in the log links there; a dived one shows what happened',
    (tester) async {
      await tester.runAsync(() async {
        final repository = DiveRepository();
        await repository.createDive(
          Dive(
            id: 'dived',
            name: 'Wreck run',
            diveNumber: 214,
            dateTime: DateTime.utc(2026, 10, 27, 9),
            maxDepth: 31,
            runtime: const Duration(minutes: 44),
          ),
        );
        await repository.createDive(
          Dive(
            id: 'entry',
            dateTime: DateTime.utc(2026, 10, 27, 12),
            isPlanned: true,
          ),
        );
        StoredSeriesDive dive(String id, String link) => StoredSeriesDive(
          plan: divePlanFromState(
            seriesDiveState(id: id).copyWith(linkedDiveId: link),
          ),
          summaryMaxDepth: 30,
          summaryRuntimeSeconds: 2400,
        );
        await DivePlanSeriesRepository().saveSeries(
          StoredSeries(
            id: 's1',
            name: 'Reef day',
            dives: [dive('a', 'dived'), dive('b', 'entry')],
          ),
        );
      });

      await tester.pumpWidget(
        testApp(
          overrides: overrides(),
          locale: const Locale('en'),
          child: const SingleChildScrollView(child: SavedPlansList()),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(find.text('1 of 2 dived'), findsOneWidget);
      expect(find.text('Wreck run'), findsOneWidget);
      expect(find.textContaining('Planned: '), findsOneWidget);
      expect(find.byTooltip('Open in dive log'), findsNWidgets(2));
      expect(find.text('B'), findsOneWidget);
      expect(find.byIcon(Icons.scuba_diving), findsWidgets);
    },
  );

  group('leaving the planner', () {
    Future<void> pumpPushed(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        testApp(
          overrides: overrides(),
          locale: const Locale('en'),
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PlanCanvasPage()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(PlanCanvasPage)));

    Future<void> addSeriesDive(WidgetTester tester) async {
      final c = containerOf(tester);
      c
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
      c.read(planSeriesNotifierProvider.notifier).addDive();
      await tester.pumpAndSettle();
    }

    Future<void> back(WidgetTester tester) async {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }

    testWidgets('asks when a series has unsaved changes; Cancel stays', (
      tester,
    ) async {
      await pumpPushed(tester);
      await addSeriesDive(tester);

      await back(tester);
      expect(find.text('Save this series?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(PlanCanvasPage), findsOneWidget);
    });

    testWidgets('Discard leaves and drops the series', (tester) async {
      await pumpPushed(tester);
      await addSeriesDive(tester);
      final c = containerOf(tester);

      await back(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(PlanCanvasPage), findsNothing);
      expect(c.read(planSeriesNotifierProvider).isSeries, isFalse);
    });

    testWidgets('an ordinary plan leaves without asking', (tester) async {
      await pumpPushed(tester);
      containerOf(tester)
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
      await tester.pumpAndSettle();

      await back(tester);

      expect(find.text('Save this series?'), findsNothing);
      expect(find.byType(PlanCanvasPage), findsNothing);
    });
  });
}
