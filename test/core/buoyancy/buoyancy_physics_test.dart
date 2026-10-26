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

    test('catalog hit via spec match for a metric preset (12 L @ 200 bar)', () {
      // An imported cylinder with specs but no preset or material used to
      // fall through to the aluminium per-liter estimate (+1.065 kg).
      expect(
        BuoyancyPhysics.tankTermKg(volumeL: 12.0, workingPressureBar: 200),
        closeTo(-2.135, 0.001),
      );
    });

    test('spec match never overrides an explicit material', () {
      expect(
        BuoyancyPhysics.tankTermKg(
          volumeL: 12.0,
          workingPressureBar: 200,
          material: TankMaterial.aluminum,
        ),
        closeTo(1.065, 0.001),
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
  });

  group('tankMaterialAssumed', () {
    test('true when neither a material nor a catalog preset is known', () {
      expect(BuoyancyPhysics.tankMaterialAssumed(), isTrue);
      expect(BuoyancyPhysics.tankMaterialAssumed(presetName: 'My D12'), isTrue);
    });

    test('false when the material is set', () {
      expect(
        BuoyancyPhysics.tankMaterialAssumed(material: TankMaterial.steel),
        isFalse,
      );
    });

    test('false when the preset is in the catalog', () {
      expect(
        BuoyancyPhysics.tankMaterialAssumed(presetName: 'steel12'),
        isFalse,
      );
    });
  });

  group('tankDryMassKg', () {
    test('catalog dry mass for al80', () {
      expect(BuoyancyPhysics.tankDryMassKg(presetName: 'al80'), 14.2);
    });

    test('catalog dry mass via spec match agrees with the buoyancy term', () {
      // tankTermKg resolves 12 L @ 200 bar to steel12; the dry mass that
      // scales the water term must come from the same catalog row.
      expect(
        BuoyancyPhysics.tankDryMassKg(volumeL: 12.0, workingPressureBar: 200),
        14.5,
      );
      expect(
        BuoyancyPhysics.tankDryMassKg(
          volumeL: 12.0,
          workingPressureBar: 200,
          material: TankMaterial.aluminum,
        ),
        closeTo(15.6, 1e-9),
      );
    });

    test('fallback scales with volume', () {
      final mass = BuoyancyPhysics.tankDryMassKg(volumeL: 12.0);
      expect(mass, greaterThan(10));
      expect(mass, lessThan(20));
    });
  });
}
