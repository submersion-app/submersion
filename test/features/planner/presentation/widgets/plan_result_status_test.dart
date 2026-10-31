import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_result_status.dart';

import '../../../../helpers/test_app.dart';

Widget _section(PlanResultView<String> view) => testApp(
  locale: const Locale('en'),
  child: PlanResultSection<String>(view: view, builder: (value) => Text(value)),
);

Future<void> _pump(WidgetTester tester, PlanResultView<String> view) async {
  await tester.pumpWidget(_section(view));
  await tester.pump();
}

void main() {
  testWidgets('a current result shows plainly, with no status', (tester) async {
    await _pump(
      tester,
      const PlanResultView(
        value: 'Required 120 L',
        status: PlanResultStatus.current,
      ),
    );

    expect(find.text('Required 120 L'), findsOneWidget);
    expect(find.text('Updating'), findsNothing);
    expect(find.text('Calculating'), findsNothing);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('a first result pending says so, with nothing beneath it', (
    tester,
  ) async {
    await _pump(
      tester,
      const PlanResultView(value: null, status: PlanResultStatus.calculating),
    );

    expect(find.text('Calculating'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('a newer result pending dims the last figures and says so', (
    tester,
  ) async {
    await _pump(
      tester,
      const PlanResultView(
        value: 'Required 120 L',
        status: PlanResultStatus.updating,
      ),
    );

    expect(find.text('Updating'), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.text('Required 120 L'),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, lessThan(1));
  });

  testWidgets('a failure with nothing to show says so in the error colour', (
    tester,
  ) async {
    await _pump(
      tester,
      const PlanResultView(value: null, status: PlanResultStatus.failed),
    );

    final text = tester.widget<Text>(find.text('Could not be calculated'));
    final context = tester.element(find.text('Could not be calculated'));
    expect(text.style?.color, Theme.of(context).colorScheme.error);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('a failure with an older value dims it and says so', (
    tester,
  ) async {
    await _pump(
      tester,
      const PlanResultView(
        value: 'Required 120 L',
        status: PlanResultStatus.failed,
      ),
    );

    expect(find.text('Could not be calculated'), findsOneWidget);
    expect(find.text('Required 120 L'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Required 120 L'),
        matching: find.byType(Opacity),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a finished null result shows nothing', (tester) async {
    await _pump(
      tester,
      const PlanResultView(value: null, status: PlanResultStatus.current),
    );

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('the status text has nothing to say for a current result', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: const PlanResultStatusText(PlanResultStatus.current),
      ),
    );

    expect(find.byType(Text), findsNothing);
  });
}
