import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';

const _resolver = TankRoleResolver();

DiveTank _tank(
  String id, {
  double o2 = 21,
  double he = 0,
  bool travel = false,
  TankRole role = TankRole.backGas,
}) => DiveTank(
  id: id,
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: o2, he: he),
  role: role,
  isTravelGas: travel,
);

PlanSegment _seg(
  String id,
  double depth,
  int minutes,
  String tankId,
  int order,
) => PlanSegment(
  id: id,
  targetDepth: depth,
  durationSeconds: minutes * 60,
  tankId: tankId,
  gasMix: const GasMix(o2: 21),
  order: order,
);

domain.DivePlan _plan({
  required List<DiveTank> tanks,
  required List<PlanSegment> segments,
  domain.PlanMode mode = domain.PlanMode.oc,
}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Roles',
  gfLow: 30,
  gfHigh: 70,
  mode: mode,
  tanks: tanks,
  segments: segments,
  createdAt: DateTime(2026, 9, 2),
  updatedAt: DateTime(2026, 9, 2),
);

Map<String, TankRole> _roles(domain.DivePlan plan) => _resolver.rolesFor(plan);

void main() {
  group('open circuit', () {
    test('a stale bailout role is re-derived, not honoured', () {
      // The bailout flag is a loop-only override: the tank editor does not
      // even offer it on an OC plan. A cylinder can still arrive carrying
      // one - picked from a saved configuration, or left over from a plan
      // that was switched from CCR to OC - and honouring it there would file
      // a deco bottle as bailout, which ContingencyService.isLosable does not
      // match, so the lost-gas contingency would silently skip it.
      final roles = _roles(
        _plan(
          tanks: [
            _tank('back'),
            _tank('deco', o2: 50, role: TankRole.bailout),
          ],
          segments: [_seg('s1', 40, 20, 'back', 0)],
        ),
      );

      expect(roles['back'], TankRole.backGas);
      expect(roles['deco'], TankRole.deco);
    });

    test('the tank the deepest leg breathes is the back gas', () {
      final plan = _plan(
        tanks: [_tank('bottom'), _tank('deco', o2: 50)],
        segments: [
          _seg('s1', 30, 3, 'bottom', 0),
          _seg('s2', 30, 20, 'bottom', 1),
        ],
      );

      expect(_roles(plan)['bottom'], TankRole.backGas);
    });

    test('a mix richer than the bottom gas is a deco gas', () {
      final plan = _plan(
        tanks: [_tank('bottom', o2: 21), _tank('deco', o2: 50)],
        segments: [_seg('s1', 30, 20, 'bottom', 0)],
      );

      expect(_roles(plan)['deco'], TankRole.deco);
    });

    test('a travel gas is a stage, never the back gas', () {
      // Leaner than the bottom mix and only breathed on the way down. If it
      // became the back gas, turn pressure and rock-bottom would be computed
      // against the wrong cylinder.
      final plan = _plan(
        tanks: [
          _tank('travel', o2: 21, travel: true),
          _tank('bottom', o2: 15, he: 55),
        ],
        segments: [
          _seg('s1', 60, 4, 'travel', 0),
          _seg('s2', 60, 15, 'bottom', 1),
        ],
      );

      final roles = _roles(plan);
      expect(roles['travel'], TankRole.stage);
      expect(roles['bottom'], TankRole.backGas);
    });

    test('a spare cylinder on the bottom mix is a stage, not a second back '
        'gas', () {
      final plan = _plan(
        tanks: [_tank('bottom'), _tank('pony')],
        segments: [_seg('s1', 25, 20, 'bottom', 0)],
      );

      final roles = _roles(plan);
      expect(roles['bottom'], TankRole.backGas);
      expect(roles['pony'], TankRole.stage);
    });

    test('the deepest leg wins even when it is not the last', () {
      // Multi-level: 40 m on trimix, then 20 m on the deco gas. The back gas
      // is the one breathed deepest, not the one breathed last.
      final plan = _plan(
        tanks: [_tank('trimix', o2: 18, he: 45), _tank('ean50', o2: 50)],
        segments: [
          _seg('s1', 40, 4, 'trimix', 0),
          _seg('s2', 40, 15, 'trimix', 1),
          _seg('s3', 20, 3, 'ean50', 2),
        ],
      );

      final roles = _roles(plan);
      expect(roles['trimix'], TankRole.backGas);
      expect(roles['ean50'], TankRole.deco);
    });

    test('falls back to the first cylinder when no segments exist yet', () {
      final plan = _plan(tanks: [_tank('a'), _tank('b', o2: 50)], segments: []);

      final roles = _roles(plan);
      expect(roles['a'], TankRole.backGas);
      expect(roles['b'], TankRole.deco);
    });
  });

  group('closed circuit', () {
    test('pure O2 is the oxygen supply and the breathed gas the diluent', () {
      final plan = _plan(
        mode: domain.PlanMode.ccr,
        tanks: [_tank('o2', o2: 100), _tank('dil', o2: 21, he: 35)],
        segments: [_seg('s1', 45, 25, 'dil', 0)],
      );

      final roles = _roles(plan);
      expect(roles['o2'], TankRole.oxygenSupply);
      expect(roles['dil'], TankRole.diluent);
    });

    test(
      'any other open-circuit cylinder carried on a loop dive is bailout',
      () {
        final plan = _plan(
          mode: domain.PlanMode.ccr,
          tanks: [
            _tank('o2', o2: 100),
            _tank('dil', o2: 21, he: 35),
            _tank('bo', o2: 21),
          ],
          segments: [_seg('s1', 45, 25, 'dil', 0)],
        );

        expect(_roles(plan)['bo'], TankRole.bailout);
      },
    );

    test('an explicit bailout flag wins over the pure-O2 derivation', () {
      // The case the numbers cannot settle: two 100% cylinders, one the
      // oxygen supply and one a deco bottle. Marking the bottle keeps it in
      // the bailout calculation instead of being read as the supply.
      final plan = _plan(
        mode: domain.PlanMode.ccr,
        tanks: [
          _tank('o2supply', o2: 100),
          _tank('decoBottle', o2: 100, role: TankRole.bailout),
          _tank('dil', o2: 21, he: 35),
        ],
        segments: [_seg('s1', 45, 25, 'dil', 0)],
      );

      final roles = _roles(plan);
      expect(roles['decoBottle'], TankRole.bailout);
      expect(roles['o2supply'], TankRole.oxygenSupply);
      expect(roles['dil'], TankRole.diluent);
    });

    test('the override does not carry over to an open-circuit plan', () {
      // The override exists because a loop plan cannot tell an O2 supply from
      // a bailout bottle by the numbers. Open circuit has no such ambiguity
      // and the tank editor does not offer the flag there, so a flag that
      // arrives on an OC plan is stale - a cylinder picked from a saved
      // configuration, or a plan switched from CCR to OC. Honouring it would
      // file the cylinder as bailout, which ContingencyService.isLosable does
      // not match, and the lost-gas contingency would skip it in silence.
      final plan = _plan(
        tanks: [
          _tank('bottom'),
          _tank('flagged', role: TankRole.bailout),
        ],
        segments: [_seg('s1', 30, 20, 'bottom', 0)],
      );

      expect(_roles(plan)['flagged'], TankRole.stage);
    });
  });

  group('apply', () {
    test('rewrites roles on a copy and leaves the input untouched', () {
      final tanks = [_tank('bottom'), _tank('deco', o2: 50)];
      final plan = _plan(
        tanks: tanks,
        segments: [_seg('s1', 30, 20, 'bottom', 0)],
      );

      final resolved = _resolver.apply(plan);

      expect(resolved.tanks[1].role, TankRole.deco);
      // The stored plan keeps the raw value, so a derived role can never be
      // mistaken for the diver's override on a later pass.
      expect(plan.tanks[1].role, TankRole.backGas);
    });

    test('an empty tank list is returned unchanged', () {
      final plan = _plan(tanks: [], segments: []);
      expect(_resolver.apply(plan).tanks, isEmpty);
    });
  });
}
