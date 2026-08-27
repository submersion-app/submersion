import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';

void main() {
  testWidgets('PlanSectionHeader renders uppercased label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PlanSectionHeader('Deco Schedule')),
      ),
    );
    expect(find.text('DECO SCHEDULE'), findsOneWidget);
  });

  testWidgets('PlanWarningRow renders icon and message in color', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlanWarningRow(
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
            message: 'Gas density high',
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    final text = tester.widget<Text>(find.text('Gas density high'));
    expect(text.style?.color, Colors.orange);
  });
}
