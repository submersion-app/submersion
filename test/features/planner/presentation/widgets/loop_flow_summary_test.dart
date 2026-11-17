import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/presentation/widgets/loop_flow_summary.dart';

import '../../../../helpers/test_app.dart';

/// The loop check beside the SCR inputs (issue #4660): the steady-state loop
/// O2 at the plan's VO2 and at resting and hard-work VO2.
void main() {
  String pct(double rate, double vo2) =>
      '${(ScrCalculator.calculateCmfSteadyStateFo2(injectionRateLpm: rate, supplyO2Percent: 50, vo2: vo2)! * 100).round()}%';

  Future<String> render(WidgetTester tester, double rate, double vo2) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: LoopFlowSummary(
          injectionRateLpm: rate,
          vo2Lpm: vo2,
          supply: const GasMix(o2: 50),
        ),
      ),
    );
    return tester.widget<Text>(find.byType(Text)).data!;
  }

  testWidgets('shows the loop O2 at the plan, resting and hard-work VO2', (
    tester,
  ) async {
    final text = await render(tester, 12, 1.3);
    expect(pct(12, 1.3), '44%');
    expect(
      text,
      'Loop O₂ on EAN50: ${pct(12, 1.3)} at this VO₂, '
      '${pct(12, ScrCalculator.restingVo2)} at rest, '
      '${pct(12, ScrCalculator.hardWorkVo2)} at hard work',
    );
  });

  testWidgets('a VO2 the flow cannot sustain reads as flow too low', (
    tester,
  ) async {
    final text = await render(tester, 3, 1.3);
    expect(text, contains('${pct(3, 1.3)} at this VO₂'));
    expect(text, contains('flow too low at hard work'));
  });
}
