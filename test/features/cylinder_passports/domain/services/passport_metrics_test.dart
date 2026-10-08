import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/gas_density.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('PassportSpecMetrics', () {
    test('ideal gas: 12 L at 232 bar is 2784 L', () {
      final m = PassportSpecMetrics.compute(
        volumeL: 12,
        workingPressureBar: 232,
        material: TankMaterial.steel,
        gasModel: GasModel.ideal,
      );
      expect(m.freeGasLiters, closeTo(2784, 1e-9));
    });

    test('real gas matches the shared gasVolume function', () {
      final m = PassportSpecMetrics.compute(
        volumeL: 11.1,
        workingPressureBar: 207,
        material: TankMaterial.aluminum,
        gasModel: GasModel.real,
      );
      expect(
        m.freeGasLiters,
        gasVolume(
          tankSizeLiters: 11.1,
          pressureBar: 207,
          o2Percent: 21,
          model: GasModel.real,
        ),
      );
    });

    test('full buoyancy is empty buoyancy minus the gas mass', () {
      // The gas mass comes from the shared mix density, the same one the
      // buoyancy twin uses, so the two can never disagree.
      final m = PassportSpecMetrics.compute(
        volumeL: 12,
        workingPressureBar: 232,
        material: TankMaterial.steel,
        gasModel: GasModel.ideal,
      );
      expect(m.emptyBuoyancyKg, isNotNull);
      final gasMass =
          12 *
          232 *
          GasDensity.mixDensityKgPerLBar(o2Percent: 21, hePercent: 0);
      expect(gasMass, closeTo(3.397, 1e-3));
      expect(m.emptyBuoyancyKg! - m.fullBuoyancyKg!, closeTo(gasMass, 1e-9));
      expect(
        m.emptyBuoyancyKg,
        BuoyancyPhysics.tankTermKg(
          volumeL: 12,
          workingPressureBar: 232,
          material: TankMaterial.steel,
          reserveBar: 0,
        ),
      );
    });

    test('the gas mass follows the diver gas model, like free gas', () {
      // Real gas holds less at 232 bar than the ideal law says, so a full
      // cylinder under the real model is lighter by exactly that gas.
      final real = PassportSpecMetrics.compute(
        volumeL: 12,
        workingPressureBar: 232,
        material: TankMaterial.steel,
        gasModel: GasModel.real,
      );
      final density = GasDensity.mixDensityKgPerLBar(
        o2Percent: 21,
        hePercent: 0,
      );
      expect(
        real.emptyBuoyancyKg! - real.fullBuoyancyKg!,
        closeTo(real.freeGasLiters! * density, 1e-9),
      );
      expect(real.freeGasLiters!, lessThan(12 * 232));
    });

    test('without a volume nothing is derived', () {
      final m = PassportSpecMetrics.compute(gasModel: GasModel.real);
      expect(m.freeGasLiters, isNull);
      expect(m.emptyBuoyancyKg, isNull);
      expect(m.fullBuoyancyKg, isNull);
    });

    test('without a pressure buoyancy is empty only', () {
      final m = PassportSpecMetrics.compute(
        volumeL: 12,
        material: TankMaterial.steel,
        gasModel: GasModel.real,
      );
      expect(m.freeGasLiters, isNull);
      expect(m.emptyBuoyancyKg, isNotNull);
      expect(m.fullBuoyancyKg, isNull);
    });
  });

  group('PassportGasLimits', () {
    test('EAN32: MOD 33.75 m at 1.4 and 40 m at 1.6, no END', () {
      final l = PassportGasLimits.compute(
        mix: const GasMix(o2: 32),
        ppO2Working: 1.4,
        ppO2Deco: 1.6,
        o2Narcotic: true,
      );
      expect(l.modWorkingM, closeTo(33.75, 1e-9));
      expect(l.modDecoM, closeTo(40.0, 1e-9));
      expect(l.endAtWorkingModM, isNull);
    });

    test('Tx18/45: END at the working MOD', () {
      // MOD = (1.4 / 0.18 - 1) x 10 = 67.777 m, ambient 7.7777 bar.
      // END (O2 narcotic) = ((7.7777 x 0.55) - 1) x 10 = 32.777 m.
      final l = PassportGasLimits.compute(
        mix: const GasMix(o2: 18, he: 45),
        ppO2Working: 1.4,
        ppO2Deco: 1.6,
        o2Narcotic: true,
      );
      expect(l.modWorkingM, closeTo(67.7777, 1e-3));
      expect(l.endAtWorkingModM, closeTo(32.7777, 1e-3));
    });
  });
}
