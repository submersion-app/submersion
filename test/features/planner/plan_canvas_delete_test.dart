import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
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

DivePlan _plan(String id, String name) => DivePlan(
  id: id,
  name: name,
  gfLow: 50,
  gfHigh: 80,
  createdAt: DateTime(2026, 7, 5),
  updatedAt: DateTime(2026, 7, 5),
);

void main() {
  late DivePlanRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DivePlanRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  // Router harness: canvas at the plan route, a stub /planning to land on.
  // Locale is pinned to English so label assertions are deterministic
  // regardless of the test environment's platform locale.
  Widget harness(String path) => testAppRouter(
    locale: const Locale('en'),
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    router: GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(
          path: '/planning',
          builder: (_, _) => const Scaffold(body: Text('planning-hub')),
        ),
        GoRoute(
          path: '/planning/dive-planner',
          builder: (_, _) => const PlanCanvasPage(),
        ),
        GoRoute(
          path: '/planning/dive-planner/:planId',
          builder: (_, state) =>
              PlanCanvasPage(planId: state.pathParameters['planId']),
        ),
      ],
    ),
  );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  testWidgets('delete removes the plan and navigates to the hub', (
    tester,
  ) async {
    await repository.savePlan(_plan('a', 'Reef dive'));

    await tester.pumpWidget(harness('/planning/dive-planner/a'));
    await tester.pumpAndSettle();

    await openMenu(tester);
    expect(find.text('Delete plan'), findsOneWidget);
    await tester.tap(find.text('Delete plan'));
    await tester.pumpAndSettle();

    // Confirmation dialog names the plan.
    expect(find.text("Delete 'Reef dive'?"), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repository.getAllPlanSummaries(), isEmpty);
    expect(find.text('planning-hub'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('undo restores the deleted plan', (tester) async {
    await repository.savePlan(_plan('a', 'Reef dive'));

    await tester.pumpWidget(harness('/planning/dive-planner/a'));
    await tester.pumpAndSettle();

    await openMenu(tester);
    await tester.tap(find.text('Delete plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repository.getAllPlanSummaries(), isEmpty);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();

    final restored = await repository.getAllPlanSummaries();
    expect(restored, hasLength(1));
    expect(restored.single.name, 'Reef dive');
  });

  testWidgets('cancel keeps the plan', (tester) async {
    await repository.savePlan(_plan('a', 'Reef dive'));

    await tester.pumpWidget(harness('/planning/dive-planner/a'));
    await tester.pumpAndSettle();

    await openMenu(tester);
    await tester.tap(find.text('Delete plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(await repository.getAllPlanSummaries(), hasLength(1));
  });

  testWidgets(
    'plan already deleted elsewhere still navigates, without an undo action',
    (tester) async {
      await repository.savePlan(_plan('a', 'Reef dive'));

      await tester.pumpWidget(harness('/planning/dive-planner/a'));
      await tester.pumpAndSettle();

      // Simulate the plan being removed via sync after the canvas opened but
      // before the user confirms. The Delete item stays visible via the
      // :planId route fallback.
      await repository.deletePlan('a');
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tester.tap(find.text('Delete plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // Navigated off the dead route and surfaced feedback, but no undo since
      // there was no snapshot to restore.
      expect(find.text('planning-hub'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Undo'), findsNothing);
    },
  );

  testWidgets('delete is hidden for a brand-new unsaved plan', (tester) async {
    await tester.pumpWidget(harness('/planning/dive-planner'));
    await tester.pumpAndSettle();

    await openMenu(tester);
    expect(find.text('Delete plan'), findsNothing);
  });
}
