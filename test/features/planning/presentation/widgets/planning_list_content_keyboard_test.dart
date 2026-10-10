import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_list_content.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('beside the pane, arrows open pane tools and pass full pages '
      '(#3065)', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String?>[];
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          divePlanSummariesProvider.overrideWith((ref) async => const []),
        ],
        child: PlanningListContent(
          showAppBar: false,
          onToolSelected: opened.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deco Calculator'));
    await tester.pumpAndSettle();
    expect(opened, ['deco-calculator']);

    // Gas Calculators opens a split view of its own, so Down only rests on it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(opened, ['deco-calculator']);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(opened, ['deco-calculator', 'weight-calculator']);

    // Up past the tools reaches the planner, a full page, which waits too.
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
    }
    expect(opened, ['deco-calculator', 'weight-calculator', 'deco-calculator']);
  });
}
