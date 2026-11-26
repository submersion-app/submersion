import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_gauges.dart';

import '../../../../helpers/test_app.dart';

/// The pitch and roll gauges and the verdict line (issue #5028).
void main() {
  Future<void> pump(WidgetTester tester, TrimResult result) =>
      tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: TrimGauges(result: result),
        ),
      );

  testWidgets('the verdict line names pitch and roll', (tester) async {
    await pump(
      tester,
      const TrimResult(pitchKgM: 1.0, rollKgM: 0.2, balancingLiftKg: 0),
    );
    expect(
      find.text('Slightly feet-heavy, rolls slightly right'),
      findsOneWidget,
    );
  });

  testWidgets('a level roll leaves the verdict to pitch alone', (tester) async {
    await pump(
      tester,
      const TrimResult(pitchKgM: -3, rollKgM: 0.1, balancingLiftKg: 0),
    );
    expect(find.text('Head-heavy'), findsWidgets);
    expect(find.textContaining('rolls'), findsNothing);
  });

  testWidgets('both gauges name their ends', (tester) async {
    await pump(
      tester,
      const TrimResult(pitchKgM: 0, rollKgM: 0, balancingLiftKg: 0),
    );
    expect(find.text('Level'), findsOneWidget);
    expect(find.text('Head-heavy'), findsOneWidget);
    expect(find.text('Feet-heavy'), findsOneWidget);
    expect(find.text('Left'), findsOneWidget);
    expect(find.text('Right'), findsOneWidget);
  });

  testWidgets('the gauges read left to right in a right-to-left language', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('he'),
        child: const TrimGauges(
          result: TrimResult(pitchKgM: 1, rollKgM: 1, balancingLiftKg: 0),
        ),
      ),
    );
    final directions = tester
        .widgetList<Directionality>(
          find.descendant(
            of: find.byType(TrimGauges),
            matching: find.byType(Directionality),
          ),
        )
        .map((d) => d.textDirection);
    expect(directions, contains(TextDirection.ltr));
  });
}
