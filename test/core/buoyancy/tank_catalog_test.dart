import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/constants/tank_presets.dart';

// Expected values computed with python3, never from recall:
//   al30stage nearEmpty @50bar reserve = 0.5 - 4.3*50*0.001225 = 0.236625
//   al40stage nearEmpty @50bar reserve = 0.9 - 5.7*50*0.001225 = 0.550875
//   aluminum per-liter fallback 4.3L = 4.3*0.15 - 4.3*50*0.001225 = 0.381625
//   aluminum per-liter fallback 5.7L = 5.7*0.15 - 5.7*50*0.001225 = 0.505875
void main() {
  group('kTankCatalog keys', () {
    test('every key is a TankPresets slug', () {
      final slugs = TankPresets.all.map((p) => p.name).toSet();
      final unknown = kTankCatalog.keys
          .where((key) => !slugs.contains(key))
          .toList();
      expect(
        unknown,
        isEmpty,
        reason:
            'Catalog keys must be TankPreset.name slugs (lowercase), not the '
            'camelCase Dart identifiers. Unknown keys silently fall through '
            'to the per-material estimate in BuoyancyPhysics.',
      );
    });

    test('every preset has a catalog entry', () {
      final missing = TankPresets.all
          .map((p) => p.name)
          .where((slug) => !kTankCatalog.containsKey(slug))
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'A preset without a catalog entry gets the coarse per-material '
            'buoyancy estimate instead of its spec-sheet values.',
      );
    });

    test('lookup by slug round-trips through TankPresets.byName', () {
      for (final key in kTankCatalog.keys) {
        expect(TankPresets.byName(key), isNotNull, reason: 'slug: $key');
      }
    });
  });

  group('stage tanks resolve to their catalog entries', () {
    test('al30stage uses catalogued buoyancy, not the aluminum estimate', () {
      expect(
        BuoyancyPhysics.tankTermKg(presetName: 'al30stage'),
        closeTo(0.236625, 1e-9),
      );
      expect(BuoyancyPhysics.tankDryMassKg(presetName: 'al30stage'), 5.5);
    });

    test('al40stage uses catalogued buoyancy on the name-only path', () {
      expect(
        BuoyancyPhysics.tankTermKg(presetName: 'al40stage'),
        closeTo(0.550875, 1e-9),
      );
      expect(BuoyancyPhysics.tankDryMassKg(presetName: 'al40stage'), 6.8);
    });

    test('al30stage resolved by specs matches resolution by slug', () {
      expect(
        BuoyancyPhysics.tankTermKg(
          presetName: TankPresets.al30Stage.name,
          volumeL: TankPresets.al30Stage.volumeLiters,
          workingPressureBar: TankPresets.al30Stage.workingPressureBar,
        ),
        closeTo(0.236625, 1e-9),
      );
    });
  });

  // A caller that has only volume and working pressure resolves through
  // TankPresets.matchBySpecs, which returns the FIRST preset within tolerance.
  // Some presets are genuinely indistinguishable that way (an AL40 and an AL40
  // Stage are both 5.7 L @ 206.843 bar), so the tie-break falls out of the
  // order of TankPresets.all. That is only safe while the tied presets share a
  // catalog row; otherwise reordering the list would silently change a
  // buoyancy prediction.
  group('spec-ambiguous presets cannot change a buoyancy result', () {
    // matchBySpecs accepts a preset when |dVolume| < 0.2 and |dPressure| < 2.0,
    // so a single (volume, pressure) pair can match two presets exactly when
    // they lie within the sum of those tolerances of each other.
    bool indistinguishable(TankPreset a, TankPreset b) =>
        (a.volumeLiters - b.volumeLiters).abs() < 0.4 &&
        (a.workingPressureBar - b.workingPressureBar).abs() < 4.0;

    test('agree on their catalog entries', () {
      // Only presets with a cuft rating are matchable by specs at all.
      final matchable = TankPresets.all
          .where((p) => p.ratedCapacityCuft != null)
          .toList();

      for (var i = 0; i < matchable.length; i++) {
        for (var j = i + 1; j < matchable.length; j++) {
          final a = matchable[i];
          final b = matchable[j];
          if (!indistinguishable(a, b)) continue;
          expect(
            kTankCatalog[a.name],
            kTankCatalog[b.name],
            reason:
                '${a.name} and ${b.name} cannot be told apart by volume and '
                'working pressure, so which one matchBySpecs returns depends '
                'on the order of TankPresets.all. They must therefore share a '
                'catalog row, or that ordering silently decides a buoyancy '
                'prediction. Give the differing preset its own resolution path '
                'before changing its numbers.',
          );
        }
      }
    });

    test('the AL40 pair is the only such pair today', () {
      final pairs = <String>[];
      final matchable = TankPresets.all
          .where((p) => p.ratedCapacityCuft != null)
          .toList();
      for (var i = 0; i < matchable.length; i++) {
        for (var j = i + 1; j < matchable.length; j++) {
          if (indistinguishable(matchable[i], matchable[j])) {
            pairs.add('${matchable[i].name}/${matchable[j].name}');
          }
        }
      }
      // Not a correctness requirement, but a new collision is worth a look:
      // it means two presets became mutually unreachable by specs.
      expect(pairs, ['al40/al40stage']);
    });
  });
}
