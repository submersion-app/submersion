import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/link_dive_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/planner_results.dart';
import '../../helpers/pump_until.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

/// The plan menu's link entries (issue #4003). A plan has to be saved before
/// anything can name it, so they wait for the first save.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Future<ProviderContainer> pumpCanvas(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...plannerResultsInline(),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
        ],
        locale: const Locale('en'),
        child: const PlanCanvasPage(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> save(WidgetTester tester, ProviderContainer container) async {
    await tester.runAsync(
      () => container.read(divePlanNotifierProvider.notifier).save(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  PopupMenuItem<String> menuItem(WidgetTester tester, String value) => tester
      .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
      .firstWhere((item) => item.value == value);

  testWidgets('an unsaved plan cannot be linked yet', (tester) async {
    await pumpCanvas(tester);
    await openMenu(tester);

    expect(find.text('Link to a logged dive'), findsOneWidget);
    expect(menuItem(tester, 'linkDive').enabled, isFalse);
    expect(find.byTooltip('Save the plan first'), findsOneWidget);
  });

  testWidgets('a saved plan opens the dive picker', (tester) async {
    final container = await pumpCanvas(tester);
    await save(tester, container);
    await openMenu(tester);

    expect(menuItem(tester, 'linkDive').enabled, isTrue);
    await tester.tap(find.text('Link to a logged dive'));
    await pumpUntilRealAsync(
      tester,
      () => find.byType(LinkDiveSheet).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(find.byType(LinkDiveSheet), findsOneWidget);
  });

  testWidgets('converting a linked plan asks before moving the link', (
    tester,
  ) async {
    final container = await pumpCanvas(tester);
    final dive = await tester.runAsync(
      () => DiveRepository().createDive(
        Dive(id: '', diveNumber: 7, dateTime: DateTime.utc(2026, 1, 1)),
      ),
    );
    container.read(divePlanNotifierProvider.notifier).setLinkedDive(dive!.id);
    await save(tester, container);
    await openMenu(tester);

    await tester.tap(find.text('Convert to Dive').last);
    await pumpUntilRealAsync(
      tester,
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(find.text("Move this plan's link?"), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).linkedDiveId, dive.id);
  });

  testWidgets('Unlink dive asks, then clears the link', (tester) async {
    final container = await pumpCanvas(tester);
    final dive = await tester.runAsync(
      () => DiveRepository().createDive(
        Dive(id: '', diveNumber: 7, dateTime: DateTime.utc(2026, 1, 1)),
      ),
    );
    container.read(divePlanNotifierProvider.notifier).setLinkedDive(dive!.id);
    await save(tester, container);
    await openMenu(tester);

    await tester.tap(find.text('Unlink dive'));
    await pumpUntilRealAsync(
      tester,
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlink'));

    await pumpUntilRealAsync(
      tester,
      () => container.read(divePlanNotifierProvider).linkedDiveId == null,
    );
  });

  testWidgets('a linked plan offers Change and Unlink', (tester) async {
    final container = await pumpCanvas(tester);
    final dive = await tester.runAsync(
      () => DiveRepository().createDive(
        Dive(id: '', diveNumber: 7, dateTime: DateTime.utc(2026, 1, 1)),
      ),
    );
    container.read(divePlanNotifierProvider.notifier).setLinkedDive(dive!.id);
    await save(tester, container);
    await pumpUntilRealAsync(
      tester,
      () =>
          container
              .read(divePlanSummariesProvider)
              .value
              ?.any((s) => s.linkedDiveNumber == 7) ??
          false,
    );
    await openMenu(tester);

    expect(find.text('Change linked dive'), findsOneWidget);
    expect(find.text('Unlink dive'), findsOneWidget);
    expect(find.text('Dived as #7'), findsOneWidget);
    expect(find.text('Link to a logged dive'), findsNothing);
  });
}
