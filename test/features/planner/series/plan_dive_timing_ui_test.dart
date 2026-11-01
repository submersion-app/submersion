import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
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

/// The start time and site in the Dive details card (issue #3565).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  final nine = DateTime.utc(2026, 10, 27, 9);

  Widget harness() => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
    ],
    locale: const Locale('en'),
    child: const PlanCanvasPage(),
  );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlanCanvasPage)));

  Future<void> pumpPlan(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness());
    containerOf(tester)
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
  }

  PlanSeriesNotifier series(WidgetTester tester) =>
      containerOf(tester).read(planSeriesNotifierProvider.notifier);

  Finder startField() => find.byKey(const Key('diveStartField'));
  Finder siteField() => find.byKey(const Key('diveSiteField'));

  testWidgets('a new plan has no start and no site', (tester) async {
    await pumpPlan(tester);

    expect(
      find.descendant(of: startField(), matching: find.text('Not set')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: siteField(), matching: find.text('No site')),
      findsOneWidget,
    );
    expect(find.byTooltip('Clear the start time'), findsNothing);
  });

  testWidgets('a later dive waits for the first dive to have a start', (
    tester,
  ) async {
    await pumpPlan(tester);
    series(tester).addDive();
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Give the first dive a start time first'),
      findsOneWidget,
    );
    final inkWell = tester.widget<InkWell>(startField());
    expect(inkWell.onTap, isNull);
  });

  testWidgets('a later dive shows the start its interval gives it', (
    tester,
  ) async {
    await pumpPlan(tester);
    series(tester).setSelectedStart(nine);
    series(tester).addDive();
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Give the first dive a start time first'),
      findsNothing,
    );
    expect(
      find.descendant(of: startField(), matching: find.text('Not set')),
      findsNothing,
    );
    // Led by its interval, so there is nothing of its own to clear.
    expect(find.byTooltip('Clear the start time'), findsNothing);
    expect(
      find.byTooltip('The surface interval follows from this start'),
      findsNothing,
    );
  });

  testWidgets('a fixed start shows the pin and can be cleared', (tester) async {
    await pumpPlan(tester);
    series(tester).setSelectedStart(nine);
    series(tester).addDive();
    final b = containerOf(tester).read(divePlanNotifierProvider);
    series(
      tester,
    ).setSelectedStart(b.startDateTime!.add(const Duration(hours: 2)));
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('The surface interval follows from this start'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Clear the start time'));
    await tester.pumpAndSettle();

    expect(
      containerOf(tester).read(planSeriesNotifierProvider).selected.fixedStart,
      isFalse,
    );
  });

  testWidgets('clearing the first dive\'s start leaves it unset', (
    tester,
  ) async {
    await pumpPlan(tester);
    series(tester).setSelectedStart(nine);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear the start time'));
    await tester.pumpAndSettle();

    expect(
      containerOf(tester).read(divePlanNotifierProvider).startDateTime,
      isNull,
    );
  });

  testWidgets('tapping the site opens the site picker', (tester) async {
    await pumpPlan(tester);

    await tester.tap(siteField());
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
  });
}
