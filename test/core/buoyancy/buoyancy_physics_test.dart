import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/constants/enums.dart';

// Expected values computed with python3 (see plan Task 8), never from
// recall:
//   waterTerm fresh = mass * (1.000/1.025 - 1)
//   waterTerm brackish = mass * (1.010/1.025 - 1)
//   al80 nearEmpty @50bar reserve = 1.7 - 11.1*50*0.001225 = 1.020125
//   steel12 nearEmpty = -1.4 - 12.0*50*0.001225 = -2.135
//   fallback aluminum 11L = 11*0.15 - 11*50*0.001225 = 0.97625
//   fallback steel 12L = 12*-0.12 - 12*50*0.001225 = -2.175
void main() {
  group('waterTermKg', () {
    test('salt water is the zero baseline', () {
      expect(
        BuoyancyPhysics.waterTermKg(waterType: WaterType.salt, totalMassKg: 90),
        0.0,
      );
    });

    test('fresh water scales with displaced mass', () {
      expect(
        BuoyancyPhysics.waterTermKg(
          waterType: WaterType.fresh,
          totalMassKg: 75,
        ),
        closeTo(-1.829268, 0.001),
      );
      expect(
        BuoyancyPhysics.waterTermKg(
          waterType: WaterType.fresh,
          totalMassKg: 90,
        ),
        closeTo(-2.195122, 0.001),
      );
      expect(
        BuoyancyPhysics.waterTermKg(
          waterType: WaterType.fresh,
          totalMassKg: 105,
        ),
        closeTo(-2.560976, 0.001),
      );
    });

    test('brackish sits between fresh and salt', () {
      expect(
        BuoyancyPhysics.waterTermKg(
          waterType: WaterType.brackish,
          totalMassKg: 90,
        ),
        closeTo(-1.317073, 0.001),
      );
    });

    test('null water type contributes nothing', () {
      expect(BuoyancyPhysics.waterTermKg(waterType: null, totalMassKg: 90), 0);
    });

    test('custom salinity wins over the water type', () {
      // 0 ppt is fresh water, so it must match the fresh-water shift even
      // when the caller still passes the salt default alongside it.
      expect(
        BuoyancyPhysics.waterTermKg(
          waterType: WaterType.salt,
          totalMassKg: 90,
          salinityPpt: 0,
        ),
        closeTo(-2.195122, 0.001),
      );
      // 14 ppt is the brackish density (1.010 kg/L).
      expect(
        BuoyancyPhysics.waterTermKg(
          waterType: null,
          totalMassKg: 90,
          salinityPpt: 14,
        ),
        closeTo(-1.317073, 0.001),
      );
      // Sea salinity is the baseline itself.
      expect(
        BuoyancyPhysics.waterTermKg(
          waterType: WaterType.fresh,
          totalMassKg: 90,
          salinityPpt: 35,
        ),
        closeTo(0.0, 0.001),
      );
    });

    test('negative salinity clamps to fresh water', () {
      expect(
        BuoyancyPhysics.waterTermKg(
          waterType: null,
          totalMassKg: 90,
          salinityPpt: -10,
        ),
        closeTo(-2.195122, 0.001),
      );
    });
  });

  group('tankTermKg', () {
    test('catalog hit by preset name (al80, near-empty at 50 bar)', () {
      expect(
        BuoyancyPhysics.tankTermKg(presetName: 'al80', volumeL: 11.1),
        closeTo(1.020125, 0.001),
      );
    });

    test('catalog hit via spec match (11.1 L @ 207 bar -> al80)', () {
      expect(
        BuoyancyPhysics.tankTermKg(
          volumeL: 11.1,
          workingPressureBar: 207,
          material: TankMaterial.aluminum,
        ),
        closeTo(1.020125, 0.001),
      );
    });

    test('catalog hit for steel12', () {
      expect(
        BuoyancyPhysics.tankTermKg(presetName: 'steel12', volumeL: 12.0),
        closeTo(-2.135, 0.001),
      );
    });

    test('material fallback when nothing matches', () {
      expect(
        BuoyancyPhysics.tankTermKg(
          volumeL: 11.0,
          material: TankMaterial.aluminum,
        ),
        closeTo(0.97625, 0.001),
      );
      expect(
        BuoyancyPhysics.tankTermKg(volumeL: 12.0, material: TankMaterial.steel),
        closeTo(-2.175, 0.001),
      );
    });

    test('steel sinks, aluminum floats (sign sanity)', () {
      final steel = BuoyancyPhysics.tankTermKg(
        volumeL: 12,
        material: TankMaterial.steel,
      );
      final aluminum = BuoyancyPhysics.tankTermKg(
        volumeL: 12,
        material: TankMaterial.aluminum,
      );
      expect(steel, lessThan(0));
      expect(aluminum, greaterThan(steel));
    });

    test('null volume uses the 11 L default without throwing', () {
      final term = BuoyancyPhysics.tankTermKg(material: TankMaterial.aluminum);
      expect(term.isFinite, isTrue);
    });

    // #3686: a UDDF import carried a D12's volume and working pressure but
    // no material, and the tank read as aluminium (+1.065 kg each instead of
    // -2.135 kg). Expected values computed with python3:
    //   steel12 near-empty = -1.4 - 12*50*0.001225 = -2.135
    //   aluminium per-liter 12 L = 12*0.15 - 12*50*0.001225 = 1.065
    test('a 12 L / 200 bar tank with no material resolves to steel12', () {
      expect(
        BuoyancyPhysics.tankTermKg(volumeL: 12.0, workingPressureBar: 200.0),
        closeTo(-2.135, 1e-9),
      );
    });

    test('an explicit material is never overridden by a size match', () {
      expect(
        BuoyancyPhysics.tankTermKg(
          volumeL: 12.0,
          workingPressureBar: 200.0,
          material: TankMaterial.aluminum,
        ),
        closeTo(1.065, 1e-9),
      );
    });
  });

  group('a preset name that contradicts the material', () {
    // The passport and the tank editor store a preset found by size alone,
    // so an aluminum cylinder the size of an HP80 can carry presetName
    // 'hp80'. Expected values computed with python3:
    //   aluminum per-liter 10.2 L = 10.2*0.15 - 10.2*50*0.001225 = 0.90525
    test('yields to the explicit material', () {
      expect(
        BuoyancyPhysics.tankTermKg(
          presetName: 'hp80',
          volumeL: 10.2,
          workingPressureBar: 237.317,
          material: TankMaterial.aluminum,
        ),
        closeTo(0.90525, 1e-9),
      );
    });

    test('still applies when the material agrees or is unset', () {
      final hp80 = BuoyancyPhysics.tankTermKg(presetName: 'hp80');
      expect(
        BuoyancyPhysics.tankTermKg(
          presetName: 'hp80',
          material: TankMaterial.steel,
        ),
        hp80,
      );
      expect(hp80, closeTo(-1.3 - 10.2 * 50 * 0.001225, 1e-9));
    });
  });

  group('tankMaterialAssumed', () {
    test('an assumed material is estimated as aluminum', () {
      expect(
        BuoyancyPhysics.tankTermKg(volumeL: 12.0, workingPressureBar: 232.0),
        BuoyancyPhysics.tankTermKg(
          volumeL: 12.0,
          material: TankMaterial.aluminum,
        ),
        reason:
            'buoyancy_tankMaterialAssumedHint tells the diver aluminum was '
            'assumed; change that string if this fallback changes.',
      );
    });

    test('true when no preset, size match or material names it', () {
      expect(
        BuoyancyPhysics.tankMaterialAssumed(
          volumeL: 12.0,
          workingPressureBar: 232.0,
        ),
        isTrue,
      );
      expect(BuoyancyPhysics.tankMaterialAssumed(volumeL: 12.0), isTrue);
    });

    test('false when the specs match a preset', () {
      expect(
        BuoyancyPhysics.tankMaterialAssumed(
          volumeL: 12.0,
          workingPressureBar: 200.0,
        ),
        isFalse,
      );
    });

    test('false for a catalogued preset name or an explicit material', () {
      expect(BuoyancyPhysics.tankMaterialAssumed(presetName: 'al80'), isFalse);
      expect(
        BuoyancyPhysics.tankMaterialAssumed(
          volumeL: 12.0,
          material: TankMaterial.steel,
        ),
        isFalse,
      );
    });
  });

  group('tankDryMassKg', () {
    test('catalog dry mass for al80', () {
      expect(BuoyancyPhysics.tankDryMassKg(presetName: 'al80'), 14.2);
    });

    test('a tank resolved by specs takes its catalogued dry mass', () {
      // 12 L / 200 bar with no material is steel12 for buoyancy, so its
      // displaced mass must come from the same row (#3686).
      expect(
        BuoyancyPhysics.tankDryMassKg(volumeL: 12.0, workingPressureBar: 200.0),
        14.5,
      );
    });

    test('fallback scales with volume', () {
      final mass = BuoyancyPhysics.tankDryMassKg(volumeL: 12.0);
      expect(mass, greaterThan(10));
      expect(mass, lessThan(20));
    });
  });
}
