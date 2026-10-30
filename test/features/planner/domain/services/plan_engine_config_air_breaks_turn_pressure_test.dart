import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// turnPressureRuleFor/turnPressureFractionFor/airBreaksFor (issue #3552,
/// follow-up to v304-306): both fields have no sensible non-null config
/// default, and a plan needs its own explicit "off" to turn tracking off
/// once the diver has opted into a non-null global default - `off` is a
/// real [domain.TurnPressureRule] value, while air breaks need a separate
/// [domain.DivePlan.airBreaksExplicitlyOff] flag since [AirBreakPolicy] has
/// no such sentinel of its own.
void main() {
  domain.DivePlan plan({
    domain.TurnPressureRule? turnPressureRule,
    double? turnPressureFraction,
    AirBreakPolicy? airBreaks,
    bool airBreaksExplicitlyOff = false,
  }) => domain.DivePlan(
    id: 'p',
    name: 'n',
    gfLow: 40,
    gfHigh: 80,
    turnPressureRule: turnPressureRule,
    turnPressureFraction: turnPressureFraction,
    airBreaks: airBreaks,
    airBreaksExplicitlyOff: airBreaksExplicitlyOff,
    createdAt: DateTime(2026, 10, 21),
    updatedAt: DateTime(2026, 10, 21),
  );

  group('turnPressureRuleFor', () {
    test('an unconfigured plan with no Settings default is unset', () {
      const config = PlanEngineConfig();
      expect(config.turnPressureRuleFor(plan()), isNull);
    });

    test("the diver's Settings default applies when the plan is unset", () {
      const config = PlanEngineConfig(
        turnPressureRule: domain.TurnPressureRule.thirds,
      );
      expect(
        config.turnPressureRuleFor(plan()),
        domain.TurnPressureRule.thirds,
      );
    });

    test("the plan's own rule wins over the diver's Settings default", () {
      const config = PlanEngineConfig(
        turnPressureRule: domain.TurnPressureRule.thirds,
      );
      expect(
        config.turnPressureRuleFor(
          plan(turnPressureRule: domain.TurnPressureRule.halves),
        ),
        domain.TurnPressureRule.halves,
      );
    });

    test(
      'off turns tracking off for this plan even with a Settings default',
      () {
        const config = PlanEngineConfig(
          turnPressureRule: domain.TurnPressureRule.thirds,
        );
        expect(
          config.turnPressureRuleFor(
            plan(turnPressureRule: domain.TurnPressureRule.off),
          ),
          domain.TurnPressureRule.off,
        );
      },
    );
  });

  group('turnPressureFractionFor', () {
    test("falls back to the diver's Settings default when unset", () {
      const config = PlanEngineConfig(turnPressureFraction: 0.4);
      expect(config.turnPressureFractionFor(plan()), 0.4);
    });

    test("the plan's own fraction wins alongside its own rule", () {
      const config = PlanEngineConfig(turnPressureFraction: 0.4);
      expect(
        config.turnPressureFractionFor(
          plan(
            turnPressureRule: domain.TurnPressureRule.custom,
            turnPressureFraction: 0.6,
          ),
        ),
        0.6,
      );
    });

    test("a plan's own Custom rule never borrows the Settings fraction", () {
      // The Setup field shows 1/3 for an unset plan fraction; the engine
      // must not silently compute with the Settings Custom fraction.
      const config = PlanEngineConfig(
        turnPressureRule: domain.TurnPressureRule.custom,
        turnPressureFraction: 0.4,
      );
      expect(
        config.turnPressureFractionFor(
          plan(turnPressureRule: domain.TurnPressureRule.custom),
        ),
        isNull,
      );
    });

    test('a plan following the Settings rule ignores a stale fraction', () {
      const config = PlanEngineConfig(
        turnPressureRule: domain.TurnPressureRule.custom,
        turnPressureFraction: 0.4,
      );
      expect(
        config.turnPressureFractionFor(plan(turnPressureFraction: 0.25)),
        0.4,
      );
    });
  });

  group('airBreaksFor', () {
    test('an unconfigured plan with no Settings default is unset', () {
      const config = PlanEngineConfig();
      expect(config.airBreaksFor(plan()), isNull);
    });

    test("the diver's Settings default applies when the plan is unset", () {
      const defaultPolicy = AirBreakPolicy(o2Seconds: 700, breakSeconds: 350);
      const config = PlanEngineConfig(airBreakPolicy: defaultPolicy);
      expect(config.airBreaksFor(plan()), same(defaultPolicy));
    });

    test("the plan's own policy wins over the diver's Settings default", () {
      const defaultPolicy = AirBreakPolicy(o2Seconds: 700, breakSeconds: 350);
      const ownPolicy = AirBreakPolicy(o2Seconds: 900, breakSeconds: 300);
      const config = PlanEngineConfig(airBreakPolicy: defaultPolicy);
      expect(config.airBreaksFor(plan(airBreaks: ownPolicy)), same(ownPolicy));
    });

    test('explicitly off turns breaks off for this plan even with a Settings '
        'default', () {
      const defaultPolicy = AirBreakPolicy(o2Seconds: 700, breakSeconds: 350);
      const config = PlanEngineConfig(airBreakPolicy: defaultPolicy);
      expect(config.airBreaksFor(plan(airBreaksExplicitlyOff: true)), isNull);
    });

    test('explicitly off wins even if the plan also carries a policy', () {
      // Should not happen through the UI (the control clears the policy
      // when picking "off"), but the resolver must still be unambiguous if
      // a stored plan somehow carries both.
      const ownPolicy = AirBreakPolicy(o2Seconds: 900, breakSeconds: 300);
      const config = PlanEngineConfig();
      expect(
        config.airBreaksFor(
          plan(airBreaks: ownPolicy, airBreaksExplicitlyOff: true),
        ),
        isNull,
      );
    });
  });
}
