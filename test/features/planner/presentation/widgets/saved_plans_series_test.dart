import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_series_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_list.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';
import '../../series/series_fixtures.dart';

/// A saved series in the saved plans sheet and list (issue #3565): one row
/// for the series, and a line for each of its dives.
void main() {
  DivePlanSummary dive(
    String id,
    int index, {
    String? name,
    String? linkedDiveId,
    int? linkedDiveNumber,
    double? depth,
    int? runtime,
  }) => DivePlanSummary(
    id: id,
    name: 'Reef day',
    updatedAt: DateTime(2026, 10, 27),
    seriesId: 's1',
    seriesIndex: index,
    diveName: name,
    linkedDiveId: linkedDiveId,
    linkedDiveNumber: linkedDiveNumber,
    maxDepth: depth,
    runtimeSeconds: runtime,
  );

  final series = [
    dive(
      'a',
      0,
      name: 'Wreck',
      linkedDiveId: 'd',
      linkedDiveNumber: 12,
      depth: 30,
      runtime: 2400,
    ),
    dive('b', 1, depth: 18, runtime: 3000),
  ];

  Future<void> pumpSheet(
    WidgetTester tester,
    List<DivePlanSummary> plans,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          divePlanSummariesProvider.overrideWith((ref) async => plans),
          divesProvider.overrideWith((ref) async => <Dive>[]),
        ],
        locale: const Locale('en'),
        child: const SavedPlansSheet(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openMenu(WidgetTester tester, Finder within) async {
    await tester.tap(
      find.descendant(
        of: within,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder line(String id) => find.byKey(ValueKey('savedSeriesDive_$id'));

  group('the sheet', () {
    testWidgets('lists a series once, with a line per dive', (tester) async {
      await pumpSheet(tester, series);

      expect(find.text('Reef day'), findsOneWidget);
      expect(find.textContaining('1 of 2 dived'), findsOneWidget);
      expect(line('a'), findsOneWidget);
      expect(line('b'), findsOneWidget);
      expect(
        find.descendant(of: line('a'), matching: find.text('Wreck')),
        findsOneWidget,
      );
      // An unnamed dive goes by its letter.
      expect(
        find.descendant(of: line('b'), matching: find.text('B')),
        findsOneWidget,
      );
    });

    testWidgets('each dive carries its own badge', (tester) async {
      await pumpSheet(tester, series);

      expect(
        find.descendant(of: line('a'), matching: find.text('Dived as #12')),
        findsOneWidget,
      );
      expect(find.text('Dived as #12'), findsOneWidget);
    });

    testWidgets('each dive has its own Link and Unlink', (tester) async {
      await pumpSheet(tester, series);

      await openMenu(tester, line('a'));
      expect(find.text('Change linked dive'), findsOneWidget);
      expect(find.text('Unlink dive'), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await openMenu(tester, line('b'));
      expect(find.text('Link to a logged dive'), findsOneWidget);
      expect(find.text('Unlink dive'), findsNothing);
    });

    testWidgets('the series row offers Rename but no link of its own', (
      tester,
    ) async {
      await pumpSheet(tester, series);

      final rowMenu = find.byType(PopupMenuButton<String>).first;
      await tester.tap(rowMenu);
      await tester.pumpAndSettle();

      expect(find.text('Rename Plan'), findsOneWidget);
      expect(find.text('Link to a logged dive'), findsNothing);
      expect(find.text('Change linked dive'), findsNothing);
    });

    testWidgets('a series cannot be picked for comparing', (tester) async {
      await pumpSheet(tester, [
        ...series,
        DivePlanSummary(id: 'p1', name: 'Solo', updatedAt: DateTime(2026)),
        DivePlanSummary(id: 'p2', name: 'Other', updatedAt: DateTime(2026)),
      ]);

      await tester.tap(find.text('Compare'));
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsNWidgets(2));
    });

    testWidgets('no Compare with one plan beside a series', (tester) async {
      await pumpSheet(tester, [
        ...series,
        DivePlanSummary(id: 'p1', name: 'Solo', updatedAt: DateTime(2026)),
      ]);

      expect(find.text('Compare'), findsNothing);
    });
  });

  group('acting on the whole series', () {
    late DivePlanSeriesRepository seriesRepository;
    late DivePlanRepository plans;

    setUp(() async {
      await setUpTestDatabase();
      plans = DivePlanRepository();
      seriesRepository = DivePlanSeriesRepository(plans: plans);
    });
    tearDown(tearDownTestDatabase);

    Future<void> saveSeries(WidgetTester tester) => tester.runAsync(
      () => seriesRepository.saveSeries(
        StoredSeries(
          id: 's1',
          name: 'Reef day',
          dives: [
            StoredSeriesDive(plan: divePlanFromState(seriesDiveState(id: 'a'))),
            StoredSeriesDive(plan: divePlanFromState(seriesDiveState(id: 'b'))),
          ],
        ),
      ),
    );

    Future<void> pumpLive(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            divesProvider.overrideWith((ref) async => <Dive>[]),
          ],
          locale: const Locale('en'),
          child: const SavedPlansSheet(),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    testWidgets('Delete removes every dive', (tester) async {
      await saveSeries(tester);
      await pumpLive(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      final remaining = await tester.runAsync(plans.getAllPlanSummaries);
      expect(remaining, isEmpty);
      expect(
        await tester.runAsync(() => seriesRepository.getSeries('s1')),
        isNull,
      );
    });

    testWidgets('Rename names the series and every dive', (tester) async {
      await saveSeries(tester);
      await pumpLive(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename Plan'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Wall day');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      final stored = await tester.runAsync(
        () => seriesRepository.getSeries('s1'),
      );
      expect(stored!.name, 'Wall day');
      expect(stored.dives.map((d) => d.plan.name), everyElement('Wall day'));
    });

    testWidgets('Rename reaches a planner holding the series', (tester) async {
      await saveSeries(tester);
      await pumpLive(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SavedPlansSheet)),
      );
      await tester.runAsync(() => openSavedPlan(container, 'b'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename Plan'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Wall day');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(container.read(divePlanNotifierProvider).name, 'Wall day');
      expect(container.read(planSeriesDirtyProvider), isFalse);
    });
  });

  testWidgets('the saved plans list shows a series once, with its dives', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          divePlanSummariesProvider.overrideWith((ref) async => series),
        ],
        locale: const Locale('en'),
        child: const SingleChildScrollView(child: SavedPlansList()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reef day'), findsOneWidget);
    expect(find.textContaining('1 of 2 dived'), findsOneWidget);
    expect(line('a'), findsOneWidget);
    expect(line('b'), findsOneWidget);
    expect(
      find.descendant(of: line('a'), matching: find.text('Dived as #12')),
      findsOneWidget,
    );
  });
}
