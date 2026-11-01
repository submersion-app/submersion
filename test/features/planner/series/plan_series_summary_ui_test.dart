import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_database.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The series summary and warnings on the plan canvas (issue #3565).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlanCanvasPage)));

  Future<void> pumpPlan(WidgetTester tester, Size size) async {
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
        ],
        locale: const Locale('en'),
        child: const PlanCanvasPage(),
      ),
    );
    containerOf(tester)
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
  }

  PlanSeriesNotifier series(WidgetTester tester) =>
      containerOf(tester).read(planSeriesNotifierProvider.notifier);

  Finder summary() => find.byKey(const Key('planSeriesSummary'));

  testWidgets('a single dive has no summary', (tester) async {
    await pumpPlan(tester, const Size(1400, 1000));
    expect(summary(), findsNothing);
  });

  testWidgets('a series shows its summary, on every dive', (tester) async {
    await pumpPlan(tester, const Size(1400, 1000));
    series(tester).addDive();
    await tester.pumpAndSettle();

    expect(summary(), findsOneWidget);
    for (final label in ['Total time', 'Highest CNS', 'Daily OTU']) {
      expect(
        find.descendant(of: summary(), matching: find.text(label)),
        findsOneWidget,
      );
    }

    series(tester).select(0);
    await tester.pumpAndSettle();
    expect(summary(), findsOneWidget);
  });

  testWidgets('no-fly is a clock time only once the series has a start', (
    tester,
  ) async {
    await pumpPlan(tester, const Size(1400, 1000));
    series(tester).addDive();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: summary(),
        matching: find.textContaining('after the last dive'),
      ),
      findsOneWidget,
    );

    series(tester).select(0);
    series(tester).setSelectedStart(DateTime.utc(2026, 10, 27, 9));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: summary(),
        matching: find.textContaining('after the last dive'),
      ),
      findsNothing,
    );
  });

  testWidgets('a short interval reaches the warnings and the dot', (
    tester,
  ) async {
    await pumpPlan(tester, const Size(1400, 1000));
    series(tester).addDive();
    containerOf(tester)
        .read(divePlanNotifierProvider.notifier)
        .setSurfaceInterval(const Duration(minutes: 5));
    await tester.pumpAndSettle();

    final c = containerOf(tester);
    expect(
      c.read(activePlanOutcomeProvider).issues.map((i) => i.type),
      contains(PlanIssueType.shortSurfaceInterval),
    );
    expect(
      c.read(planSeriesResultsProvider)[1].outcome.issues.map((i) => i.type),
      contains(PlanIssueType.shortSurfaceInterval),
    );
    expect(find.bySemanticsLabel('Dive B has warnings'), findsWidgets);
  });

  testWidgets('it fits a phone', (tester) async {
    await pumpPlan(tester, const Size(420, 900));
    series(tester).addDive();
    containerOf(tester).read(plannerPhoneTabProvider.notifier).state = 3;
    await tester.pumpAndSettle();

    expect(summary(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
