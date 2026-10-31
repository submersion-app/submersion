import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = DiveTank(
  id: 'air',
  volume: 24,
  startPressure: 200,
  gasMix: GasMix(o2: 21),
  role: TankRole.backGas,
);

// Labelled back gas and breathed by no segment, so [compute] derives deco.
const _ean50 = DiveTank(
  id: 'ean50',
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: 50),
  role: TankRole.backGas,
);

domain.DivePlan _plan({
  double? ascentRate,
  double? ppO2Deco,
  WaterType? waterType,
}) => domain.DivePlan(
  id: 'p',
  name: 'p',
  gfLow: 30,
  gfHigh: 70,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  ascentRate: ascentRate,
  ppO2Deco: ppO2Deco,
  waterType: waterType,
  tanks: const [_air, _ean50],
  segments: [
    PlanSegment.hold(
      id: 's0',
      depth: 30,
      durationMinutes: 20,
      tankId: 'air',
      gasMix: const GasMix(o2: 21),
    ),
  ],
);

double _ean50Mod(AscentGasPlan plan) =>
    (plan as OptimalOcAscentGas).gases[1].maxPpO2Mod;

void main() {
  group('schedulePolicyFor', () {
    const engine = PlanEngine(config: PlanEngineConfig(ascentRate: 6));

    test('a rate set on the plan wins over the config', () {
      expect(engine.schedulePolicyFor(_plan(ascentRate: 3)).ascentRate, 3);
    });

    test('a rate the plan leaves unset follows the config', () {
      expect(engine.schedulePolicyFor(_plan()).ascentRate, 6);
    });
  });

  group('ocAscentPlanFor', () {
    const engine = PlanEngine();

    test('resolves cylinder roles, as compute does', () {
      // EAN50 reaches 22 m at the deco limit of 1.6, 18 m at the bottom
      // limit of 1.4 its stored role would give it.
      expect(_ean50Mod(engine.ocAscentPlanFor(_plan())), greaterThan(20));
    });

    test("uses the plan's own deco limit", () {
      expect(
        _ean50Mod(engine.ocAscentPlanFor(_plan(ppO2Deco: 1.4))),
        lessThan(20),
      );
    });

    test("measures switch depths in the plan's water", () {
      final salt = engine.ocAscentPlanFor(_plan(waterType: WaterType.salt));
      final fresh = engine.ocAscentPlanFor(_plan(waterType: WaterType.fresh));
      expect(_ean50Mod(fresh), greaterThan(_ean50Mod(salt)));
    });
  });
}
