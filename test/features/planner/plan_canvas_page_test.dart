import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_settings_panel.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_canvas_chart.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

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
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Widget harness() => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: const PlanCanvasPage(),
  );

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void seed(WidgetTester tester) {
    ProviderScope.containerOf(tester.element(find.byType(PlanCanvasPage)))
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
  }

  testWidgets('phone layout shows chart, chips, segments, and a sheet', (
    tester,
  ) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    seed(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PlanCanvasChart), findsOneWidget);
    expect(find.byType(PlanStatusChips), findsOneWidget);
    expect(find.byType(SegmentList), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
  });

  testWidgets('wide layout shows settings panel and no draggable sheet', (
    tester,
  ) async {
    await setSize(tester, const Size(1400, 900));
    await tester.pumpWidget(harness());
    seed(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PlanSettingsPanel), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });

  testWidgets('save action clears the dirty flag', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).isDirty, isTrue);

    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).isDirty, isFalse);
  });

  Future<void> openMenu(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('quick-plan menu opens the simple-plan dialog', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await openMenu(tester, 'Quick Plan');
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('saved menu opens the saved-plans sheet', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await openMenu(tester, 'Saved plans');
    expect(find.text('No saved plans yet'), findsOneWidget);
  });

  testWidgets('settings menu opens a settings sheet', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await openMenu(tester, 'Plan Settings');
    expect(find.byType(PlanSettingsPanel), findsOneWidget);
  });

  testWidgets('reset menu shows a confirm dialog and clears the plan', (
    tester,
  ) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).segments, isNotEmpty);

    await openMenu(tester, 'Reset Plan');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Reset').last);
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).segments, isEmpty);
  });

  testWidgets('convert menu surfaces a message', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    seed(tester);
    await tester.pumpAndSettle();
    await openMenu(tester, 'Convert to Dive');
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('tapping the title renames the plan', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Dive Plan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Reef wall');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).name, 'Reef wall');
  });

  testWidgets('wide issues chip scrolls the results pane without leaking', (
    tester,
  ) async {
    await setSize(tester, const Size(1400, 900));
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    // A deep air plan trips a critical gas-density issue, so an issues chip
    // renders and the tap has a target.
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 50, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();

    final issuesChip = find.textContaining('issue');
    expect(issuesChip, findsWidgets);
    await tester.tap(issuesChip.first);
    await tester.pumpAndSettle();
    // No exception = the hoisted controller is wired and disposed by the page.
  });
}
