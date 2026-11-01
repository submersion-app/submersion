import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/ascent/ascent_travel_spans.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/planner/domain/services/bailout_chart_support.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

void main() {
  test('the worst-case ascent samples a gas switch inside a leg', () {
    const policy = SchedulePolicy();
    final model = BuhlmannGf(policy: policy);
    final gases = OptimalOcAscentGas(
      maxPpO2: 1.6,
      gases: const [
        AvailableGas(fN2: 0.79, fHe: 0, maxPpO2Mod: 66),
        AvailableGas(fN2: 0.50, fHe: 0, maxPpO2Mod: 21),
      ],
    );
    final state = model.applySegment(
      model.initial(),
      const DecoSegment(startDepth: 28, endDepth: 28, durationSeconds: 600),
      const OpenCircuit(fO2: 0.21, fHe: 0),
    );

    final trace = worstCaseCeilingTrace(
      model: model,
      points: const [
        BailoutPoint(
          runtimeSeconds: 600,
          depthMeters: 28,
          ttsSeconds: 200,
          litersRequired: 0,
          schedule: DecoSchedule(stops: [], ttsSeconds: 200),
        ),
      ],
      states: [state],
      worstIndex: 0,
      bailoutPlan: gases,
      policy: policy,
    );

    final toSwitch = ascentTravelSpans(
      policy,
      gases,
      fromDepth: 28,
      stopDepths: const [],
    ).first;
    expect(toSwitch.toDepth, 21);
    expect(
      toSwitch.seconds % PlanEngine.ceilingSampleSeconds,
      isNot(0),
      reason: 'a switch on the sample grid would pass without the cut',
    );
    expect(trace.map((point) => point.$1), contains(600 + toSwitch.seconds));
  });
}
