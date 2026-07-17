import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_rail.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_shell.dart';

import '../../helpers/test_app.dart';

Widget _shellAt(String path) {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      ShellRoute(
        builder: (context, state, child) => PlanningShell(child: child),
        routes: [
          GoRoute(
            path: '/planning',
            builder: (_, _) => const Text('HUB'),
            routes: [
              GoRoute(
                path: 'dive-planner',
                builder: (_, _) => const Text('PLANNER'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  return testAppRouter(router: router);
}

void main() {
  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('wide hub renders full width with no rail and no sidebar', (
    tester,
  ) async {
    await setSize(tester, const Size(1400, 900));
    await tester.pumpWidget(_shellAt('/planning'));
    await tester.pumpAndSettle();
    expect(find.text('HUB'), findsOneWidget);
    expect(find.byType(PlanningRail), findsNothing);
  });

  testWidgets('wide tool route shows the rail beside the tool', (tester) async {
    await setSize(tester, const Size(1400, 900));
    await tester.pumpWidget(_shellAt('/planning/dive-planner'));
    await tester.pumpAndSettle();
    expect(find.text('PLANNER'), findsOneWidget);
    expect(find.byType(PlanningRail), findsOneWidget);
  });

  testWidgets('rail back button returns to the hub', (tester) async {
    await setSize(tester, const Size(1400, 900));
    await tester.pumpWidget(_shellAt('/planning/dive-planner'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('HUB'), findsOneWidget);
    expect(find.byType(PlanningRail), findsNothing);
  });

  testWidgets('narrow returns the child bare', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(_shellAt('/planning/dive-planner'));
    await tester.pumpAndSettle();
    expect(find.text('PLANNER'), findsOneWidget);
    expect(find.byType(PlanningRail), findsNothing);
  });
}
