import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  final hostKey = GlobalKey();

  /// Keeps one ProviderScope alive while the planner page comes and goes, so
  /// the notifier can be inspected after the page is disposed.
  Widget harness(ValueNotifier<bool> showPlanner) => testApp(
    overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
    locale: const Locale('en'),
    child: KeyedSubtree(
      key: hostKey,
      child: ValueListenableBuilder<bool>(
        valueListenable: showPlanner,
        builder: (_, show, _) =>
            show ? const PlanCanvasPage() : const SizedBox.shrink(),
      ),
    ),
  );

  DivePlanNotifier notifierOf(WidgetTester tester) => ProviderScope.containerOf(
    hostKey.currentContext!,
  ).read(divePlanNotifierProvider.notifier);

  testWidgets('leaving a replan resets the planner to a fresh plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final showPlanner = ValueNotifier(true);
    await tester.pumpWidget(harness(showPlanner));
    await tester.pumpAndSettle();

    final notifier = notifierOf(tester);
    notifier.addSimplePlan(maxDepth: 40, bottomTimeMinutes: 20);
    final container = ProviderScope.containerOf(hostKey.currentContext!);
    notifier.loadPlan(
      container.read(divePlanNotifierProvider).copyWith(sourceDiveId: 'dive-1'),
    );
    await tester.pump();
    expect(container.read(divePlanNotifierProvider).segments, isNotEmpty);

    showPlanner.value = false;
    await tester.pumpAndSettle();

    final after = container.read(divePlanNotifierProvider);
    expect(after.sourceDiveId, isNull);
    expect(after.segments, isEmpty);
  });

  testWidgets('leaving an ordinary plan keeps it', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final showPlanner = ValueNotifier(true);
    await tester.pumpWidget(harness(showPlanner));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(hostKey.currentContext!);
    notifierOf(tester).addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pump();

    showPlanner.value = false;
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).segments, isNotEmpty);
  });
}
