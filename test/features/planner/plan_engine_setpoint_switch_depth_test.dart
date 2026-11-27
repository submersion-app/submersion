import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// The setpoint switch depth resolves through the diver's Settings (#3793):
/// the plan's own value wins, Off holds the low setpoint throughout, and an
/// unset plan follows the config.
const _diluent = GasMix(o2: 18, he: 45);
const _oxygen = GasMix(o2: 100);

DiveTank _tank(String id, GasMix gas, TankRole role) =>
    DiveTank(id: id, volume: 12, startPressure: 200, gasMix: gas, role: role);

domain.DivePlan _plan({
  double? setpointSwitchDepth,
  bool setpointSwitchOff = false,
  double depth = 20,
  int minutes = 10,
}) => domain.DivePlan(
  id: 'switch',
  name: 'Switch',
  mode: domain.PlanMode.ccr,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  problemSolvingMinutes: 0,
  setpointSwitchDepth: setpointSwitchDepth,
  setpointSwitchOff: setpointSwitchOff,
  tanks: [
    _tank('dil', _diluent, TankRole.diluent),
    _tank('o2', _oxygen, TankRole.oxygenSupply),
  ],
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: depth,
      tankId: 'dil',
      gasMix: _diluent,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: depth,
      durationMinutes: minutes,
      tankId: 'dil',
      gasMix: _diluent,
      order: 1,
    ),
  ],
);

void main() {
  group('PlanEngineConfig.setpointHighFor never resolves below the low', () {
    const config = PlanEngineConfig(ccrSetpointLow: 0.7, ccrSetpointHigh: 0.9);

    test('a custom low above the Settings high lifts the high to it', () {
      final plan = _plan().copyWith(setpointLow: 1.0);
      expect(config.setpointLowFor(plan), 1.0);
      expect(config.setpointHighFor(plan), 1.0);
    });

    test('a custom high below the Settings low resolves to the low', () {
      final plan = _plan().copyWith(setpointHigh: 0.6);
      expect(config.setpointHighFor(plan), 0.7);
    });

    test('an ordinary pair is untouched', () {
      final plan = _plan().copyWith(setpointLow: 0.8, setpointHigh: 1.2);
      expect(config.setpointLowFor(plan), 0.8);
      expect(config.setpointHighFor(plan), 1.2);
      expect(config.setpointHighFor(_plan()), 0.9);
    });
  });

  group('PlanEngineConfig.setpointSwitchDepthFor', () {
    const config = PlanEngineConfig(ccrSetpointSwitchDepth: 6.0);

    test('an unset plan follows the config', () {
      expect(config.setpointSwitchDepthFor(_plan()), 6.0);
    });

    test('the plan\'s own depth wins over the config', () {
      expect(config.setpointSwitchDepthFor(_plan(setpointSwitchDepth: 12)), 12);
    });

    test('a plan depth of 0 is a value, not unset', () {
      expect(config.setpointSwitchDepthFor(_plan(setpointSwitchDepth: 0)), 0);
    });

    test('Off resolves to no switch, whatever else is set', () {
      expect(
        config.setpointSwitchDepthFor(_plan(setpointSwitchOff: true)),
        double.infinity,
      );
      expect(
        config.setpointSwitchDepthFor(
          _plan(setpointSwitchDepth: 12, setpointSwitchOff: true),
        ),
        double.infinity,
      );
    });

    test('the default config is the spec depth', () {
      expect(
        const PlanEngineConfig().setpointSwitchDepthFor(_plan()),
        domain.DivePlan.specSetpointSwitchDepth,
      );
    });

    test('resolvedFor keeps the depth', () {
      expect(config.resolvedFor(_plan()).ccrSetpointSwitchDepth, 6.0);
    });
  });

  group('setpointAt', () {
    const config = PlanEngineConfig(ccrSetpointSwitchDepth: 6.0);

    test('changes setpoint at the config depth when the plan sets none', () {
      final plan = _plan();
      expect(setpointAt(plan, 8, config: config), config.setpointHighFor(plan));
      expect(setpointAt(plan, 5, config: config), config.setpointLowFor(plan));
      // At the spec depth of 10 m, 8 m is still on the low setpoint.
      expect(
        setpointAt(plan, 8, config: const PlanEngineConfig()),
        const PlanEngineConfig().setpointLowFor(plan),
      );
    });

    test('Off holds the low setpoint at any depth', () {
      final plan = _plan(setpointSwitchOff: true);
      expect(setpointAt(plan, 90, config: config), config.setpointLowFor(plan));
    });
  });

  group('PlanEngine', () {
    test('the config depth equals the same depth set on the plan', () {
      final viaConfig = const PlanEngine(
        config: PlanEngineConfig(ccrSetpointSwitchDepth: 6.0),
      ).compute(_plan());
      final viaPlan = const PlanEngine().compute(
        _plan(setpointSwitchDepth: 6.0),
      );
      expect(viaConfig.cnsEnd, closeTo(viaPlan.cnsEnd, 1e-9));
      expect(viaConfig.otuTotal, closeTo(viaPlan.otuTotal, 1e-9));
      expect(viaConfig.runtimeSeconds, viaPlan.runtimeSeconds);
    });

    test('a shallower config depth changes what the ascent breathes', () {
      final shallow = const PlanEngine(
        config: PlanEngineConfig(ccrSetpointSwitchDepth: 6.0),
      ).compute(_plan());
      final spec = const PlanEngine().compute(_plan());
      expect(shallow.otuTotal, isNot(closeTo(spec.otuTotal, 1e-9)));
    });

    test('Off breathes the low setpoint throughout, with no cut', () {
      final off = const PlanEngine().compute(_plan(setpointSwitchOff: true));
      // A switch deeper than the dive is the same as no switch at all.
      final deep = const PlanEngine().compute(_plan(setpointSwitchDepth: 1000));
      expect(off.cnsEnd, closeTo(deep.cnsEnd, 1e-9));
      expect(off.otuTotal, closeTo(deep.otuTotal, 1e-9));
      expect(off.runtimeSeconds, deep.runtimeSeconds);
      expect(off.cnsEnd.isFinite, isTrue);
      expect(off.otuTotal.isFinite, isTrue);
    });
  });
}
