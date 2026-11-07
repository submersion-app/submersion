import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
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

    test('nothing to draw gives nothing to anyone', () {
      final share = balancedShare(0, const [
        (id: 'a', capacityLiters: 2000, usedLiters: 0),
        (id: 'b', capacityLiters: 2000, usedLiters: 0),
      ]);

      expect(share.values.every((v) => v == 0), isTrue);
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
