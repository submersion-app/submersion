import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/services/same_mix_share.dart';

/// Cylinders carrying the same mix share what is breathed from that mix so
/// they end at the same fraction of their own capacity (#4138).
void main() {
  group('balancedShare', () {
    test('two equal fresh cylinders split the draw in half', () {
      final share = balancedShare(1000, const [
        (id: 'a', capacityLiters: 2000, usedLiters: 0),
        (id: 'b', capacityLiters: 2000, usedLiters: 0),
      ]);

      expect(share['a'], closeTo(500, 1e-9));
      expect(share['b'], closeTo(500, 1e-9));
    });

    test('unequal cylinders split in proportion to capacity', () {
      final share = balancedShare(900, const [
        (id: 'small', capacityLiters: 1000, usedLiters: 0),
        (id: 'big', capacityLiters: 2000, usedLiters: 0),
      ]);

      expect(share['small'], closeTo(300, 1e-9));
      expect(share['big'], closeTo(600, 1e-9));
    });

    test('the fuller cylinder is breathed first until they level out', () {
      // a is already 40% down; b is full. 600 L brings b to 30% on its own,
      // so a takes nothing.
      final share = balancedShare(600, const [
        (id: 'a', capacityLiters: 2000, usedLiters: 800),
        (id: 'b', capacityLiters: 2000, usedLiters: 0),
      ]);

      expect(share['a'] ?? 0, closeTo(0, 1e-9));
      expect(share['b'], closeTo(600, 1e-9));
    });

    test('once level, both cylinders take the rest together', () {
      // b needs 800 L to reach a's 40%; the other 400 L split evenly.
      final share = balancedShare(1200, const [
        (id: 'a', capacityLiters: 2000, usedLiters: 800),
        (id: 'b', capacityLiters: 2000, usedLiters: 0),
      ]);

      expect(share['a'], closeTo(200, 1e-9));
      expect(share['b'], closeTo(1000, 1e-9));
    });

    test('a shortfall takes every cylinder past empty together', () {
      final share = balancedShare(5000, const [
        (id: 'a', capacityLiters: 2000, usedLiters: 0),
        (id: 'b', capacityLiters: 2000, usedLiters: 0),
      ]);

      expect(share['a'], closeTo(2500, 1e-9));
      expect(share['b'], closeTo(2500, 1e-9));
    });

    test('shares always add up to the amount drawn', () {
      final share = balancedShare(1234.5, const [
        (id: 'a', capacityLiters: 1400, usedLiters: 900),
        (id: 'b', capacityLiters: 2200, usedLiters: 100),
        (id: 'c', capacityLiters: 800, usedLiters: 50),
      ]);

      expect(
        share.values.fold<double>(0, (sum, v) => sum + v),
        closeTo(1234.5, 1e-9),
      );
    });

    test('a cylinder of unknown capacity takes nothing beside known ones', () {
      final share = balancedShare(1000, const [
        (id: 'known', capacityLiters: 2000, usedLiters: 0),
        (id: 'unknown', capacityLiters: 0, usedLiters: 0),
      ]);

      expect(share['known'], closeTo(1000, 1e-9));
      expect(share['unknown'] ?? 0, 0);
    });

    test('with no capacity known anywhere the draw splits evenly', () {
      final share = balancedShare(1000, const [
        (id: 'a', capacityLiters: 0, usedLiters: 0),
        (id: 'b', capacityLiters: 0, usedLiters: 0),
      ]);

      expect(share['a'], closeTo(500, 1e-9));
      expect(share['b'], closeTo(500, 1e-9));
    });

    test('a single cylinder takes the whole draw', () {
      final share = balancedShare(700, const [
        (id: 'only', capacityLiters: 2000, usedLiters: 300),
      ]);

      expect(share, {'only': 700});
    });

    test('no cylinders take no share', () {
      expect(balancedShare(500, const []), isEmpty);
    });

    test('nothing to draw gives nothing to anyone', () {
      final share = balancedShare(0, const [
        (id: 'a', capacityLiters: 2000, usedLiters: 0),
        (id: 'b', capacityLiters: 2000, usedLiters: 0),
      ]);

      expect(share.values.every((v) => v == 0), isTrue);
    });
  });

  group('balancedDrawPhases', () {
    test('a fuller cylinder draws alone until the pair is level', () {
      // b needs 800 L to reach a's 40%, the first two thirds of the draw;
      // the last 400 L come from both.
      final phases = balancedDrawPhases(1200, const [
        (id: 'a', capacityLiters: 2000, usedLiters: 800),
        (id: 'b', capacityLiters: 2000, usedLiters: 0),
      ]);

      expect(phases, hasLength(2));
      expect(phases.first.fraction, closeTo(2 / 3, 1e-9));
      expect(phases.first.liters.keys, ['b']);
      expect(phases.first.liters['b'], closeTo(800, 1e-9));
      expect(phases.last.fraction, closeTo(1 / 3, 1e-9));
      expect(phases.last.liters['a'], closeTo(200, 1e-9));
      expect(phases.last.liters['b'], closeTo(200, 1e-9));
    });

    test('a level pair draws together for the whole draw', () {
      final phases = balancedDrawPhases(600, const [
        (id: 'a', capacityLiters: 1000, usedLiters: 0),
        (id: 'b', capacityLiters: 2000, usedLiters: 0),
      ]);

      expect(phases, hasLength(1));
      expect(phases.single.fraction, closeTo(1, 1e-9));
      expect(phases.single.liters['a'], closeTo(200, 1e-9));
      expect(phases.single.liters['b'], closeTo(400, 1e-9));
    });

    test('a draw ending before the levels meet is one phase', () {
      final phases = balancedDrawPhases(300, const [
        (id: 'a', capacityLiters: 2000, usedLiters: 800),
        (id: 'b', capacityLiters: 2000, usedLiters: 0),
      ]);

      expect(phases, hasLength(1));
      expect(phases.single.liters, {'b': 300});
    });

    test('phases add up to balancedShare and to the whole draw', () {
      const cylinders = [
        (id: 'a', capacityLiters: 1400.0, usedLiters: 900.0),
        (id: 'b', capacityLiters: 2200.0, usedLiters: 100.0),
        (id: 'c', capacityLiters: 800.0, usedLiters: 50.0),
      ];
      final phases = balancedDrawPhases(1234.5, cylinders);
      final share = balancedShare(1234.5, cylinders);
      final summed = <String, double>{};
      for (final phase in phases) {
        for (final MapEntry(:key, :value) in phase.liters.entries) {
          summed[key] = (summed[key] ?? 0) + value;
        }
      }

      expect(
        phases.fold<double>(0, (sum, p) => sum + p.fraction),
        closeTo(1, 1e-9),
      );
      for (final MapEntry(:key, :value) in share.entries) {
        expect(summed[key] ?? 0, closeTo(value, 1e-9), reason: key);
      }
    });

    test('nothing to draw has no phases', () {
      expect(
        balancedDrawPhases(0, const [
          (id: 'a', capacityLiters: 2000, usedLiters: 0),
        ]),
        isEmpty,
      );
    });
  });

  group('fillCapacityLiters', () {
    const air = GasMix(o2: 21);

    test('a cylinder with no fill holds nothing', () {
      expect(
        fillCapacityLiters(
          const DiveTank(id: 'a', volume: 12, gasMix: air),
          GasModel.ideal,
        ),
        0,
      );
    });

    test('size times fill on the ideal model, 11 L when unset', () {
      expect(
        fillCapacityLiters(
          const DiveTank(id: 'a', volume: 12, startPressure: 200, gasMix: air),
          GasModel.ideal,
        ),
        closeTo(2400, 1e-6),
      );
      expect(
        fillCapacityLiters(
          const DiveTank(id: 'a', startPressure: 200, gasMix: air),
          GasModel.ideal,
        ),
        closeTo(2200, 1e-6),
      );
    });
  });

  group('spreadAcrossSameMix', () {
    const air = GasMix(o2: 21);
    const ean50 = GasMix(o2: 50);
    const tanks = [
      DiveTank(id: 'a', gasMix: air, role: TankRole.bailout),
      DiveTank(id: 'b', gasMix: air, role: TankRole.bailout),
      DiveTank(id: 'deco', gasMix: ean50, role: TankRole.bailout),
    ];

    test('spreads each mix across its cylinders, balanced on prior use', () {
      final spread = spreadAcrossSameMix(
        const {'a': 1000, 'deco': 300},
        tanks: tanks,
        capacityOf: (_) => 2000,
        alreadyUsed: const {'a': 400},
      );

      expect(spread['a'], closeTo(300, 1e-9));
      expect(spread['b'], closeTo(700, 1e-9));
      expect(spread['deco'], closeTo(300, 1e-9));
    });

    test('keeps a key that names no cylinder as it is', () {
      final spread = spreadAcrossSameMix(
        const {'': 250},
        tanks: tanks,
        capacityOf: (_) => 2000,
      );

      expect(spread, {'': 250});
    });
  });

  group('sameMixTanks', () {
    const air = GasMix(o2: 21);
    const nitrox = GasMix(o2: 32);
    DiveTank tank(String id, GasMix mix) =>
        DiveTank(id: id, gasMix: mix, role: TankRole.bailout);

    test('keeps the cylinders whose mix matches, in their own order', () {
      final tanks = [tank('a', air), tank('b', nitrox), tank('c', air)];

      expect(sameMixTanks(tanks, fO2: 0.21, fHe: 0).map((t) => t.id), [
        'a',
        'c',
      ]);
    });

    test('a deco stage shares only with deco and stage cylinders', () {
      final tanks = [
        const DiveTank(id: 'back', gasMix: nitrox),
        const DiveTank(id: 'deco', gasMix: nitrox, role: TankRole.deco),
        const DiveTank(id: 'stage', gasMix: nitrox, role: TankRole.stage),
      ];

      expect(sameMixShareGroup(tanks, 'deco').map((t) => t.id), [
        'deco',
        'stage',
      ]);
      expect(sameMixShareGroup(tanks, 'back').map((t) => t.id), ['back']);
    });

    test('an id on no cylinder has no group', () {
      expect(sameMixShareGroup([tank('a', air)], 'gone'), isEmpty);
      expect(sameMixShareGroup([tank('a', air)], null), isEmpty);
    });

    test('tolerates the rounding a gas plan carries', () {
      final tanks = [tank('a', air)];

      expect(sameMixTanks(tanks, fO2: 0.2104, fHe: 0.0001), hasLength(1));
    });
  });
}
