import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_gas_row.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_issue_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';

// Issue #4475: the problem-solving gas has its own line, and minimum gas
// names the pressure the cylinder leaves the bottom with.

const _units = UnitFormatter(AppSettings());

Future<String> _message(WidgetTester tester, PlanIssue issue) async {
  late String message;
  await tester.pumpWidget(
    testApp(
      child: Builder(
        builder: (context) {
          message = planIssueMessage(context, issue, _units);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return message;
}

void main() {
  testWidgets('the warning names the bottom-end pressure and rock bottom', (
    tester,
  ) async {
    final message = await _message(
      tester,
      const PlanIssue(
        type: PlanIssueType.minGasViolation,
        severity: PlanIssueSeverity.warning,
        message: '',
        value: 95,
        threshold: 102,
      ),
    );

    expect(
      message,
      'Leaves the bottom with 95 bar, under the rock-bottom minimum of '
      '102 bar: no gas held back for problem-solving time',
    );
  });

  testWidgets('the critical one names the ascent-only minimum', (tester) async {
    final message = await _message(
      tester,
      const PlanIssue(
        type: PlanIssueType.minGasAscentViolation,
        severity: PlanIssueSeverity.critical,
        message: '',
        value: 40,
        threshold: 52,
      ),
    );

    expect(
      message,
      'Leaves the bottom with 40 bar, under the 52 bar an emergency ascent '
      'needs',
    );
  });

  Future<void> pumpRow(WidgetTester tester, PlanTankUsage usage) =>
      tester.pumpWidget(
        testApp(
          child: PlanGasRow(usage: usage, label: 'Back gas', units: _units),
        ),
      );

  testWidgets('a gas row shows the problem-solving gas on its own', (
    tester,
  ) async {
    await pumpRow(
      tester,
      const PlanTankUsage(
        tankId: 'back',
        litersUsed: 1200,
        totalLiters: 2400,
        remainingPressure: 100,
        startPressure: 200,
        percentUsed: 50,
        problemSolvingLiters: 240,
        problemSolvingPressure: 20,
      ),
    );

    expect(find.text('used: 1200L/100bar'), findsOneWidget);
    expect(find.text('problem solving: 240L/20bar'), findsOneWidget);
  });

  testWidgets('a cylinder holding none has no problem-solving line', (
    tester,
  ) async {
    await pumpRow(
      tester,
      const PlanTankUsage(
        tankId: 'deco',
        litersUsed: 300,
        totalLiters: 2400,
        remainingPressure: 175,
        startPressure: 200,
        percentUsed: 12.5,
      ),
    );

    expect(find.textContaining('problem solving'), findsNothing);
  });
}
