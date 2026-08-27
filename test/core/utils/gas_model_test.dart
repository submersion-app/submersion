import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';

/// Gas model selection and the 1 bar reference pressure (issue #828).
///
/// Free gas volumes are expressed in liters at 1 bar so that they divide
/// cleanly by the ambient pressure ratio `depth / 10 + 1`, which is also in
/// bar. Before #828 volumes were referenced to 1 atm while the ambient ratio
/// stayed in bar, understating every volumetric SAC rate by ~1.3%.
void main() {
  group('gasVolume reference pressure', () {
    test('ideal model returns exactly tank size times pressure', () {
      expect(
        gasVolume(
          tankSizeLiters: 12,
          pressureBar: 200,
          o2Percent: 21,
          model: GasModel.ideal,
        ),
        closeTo(2400.0, 1e-9),
      );
    });

    test('real model applies compressibility against the same reference', () {
      expect(
        gasVolume(
          tankSizeLiters: 12,
          pressureBar: 200,
          o2Percent: 21,
          model: GasModel.real,
        ),
        closeTo(2317.13, 0.01),
      );
    });

    test('real model holds less gas than ideal for air at 200 bar', () {
      final ideal = gasVolume(
        tankSizeLiters: 12,
        pressureBar: 200,
        o2Percent: 21,
        model: GasModel.ideal,
      );
      final real = gasVolume(
        tankSizeLiters: 12,
        pressureBar: 200,
        o2Percent: 21,
        model: GasModel.real,
      );
      expect(real, lessThan(ideal));
    });

    test('the two models agree at surface pressure', () {
      final ideal = gasVolume(
        tankSizeLiters: 12,
        pressureBar: 1,
        o2Percent: 21,
        model: GasModel.ideal,
      );
      final real = gasVolume(
        tankSizeLiters: 12,
        pressureBar: 1,
        o2Percent: 21,
        model: GasModel.real,
      );
      expect(real, closeTo(ideal, 0.01));
    });

    test('both models return 0 at or below 0 bar', () {
      for (final model in GasModel.values) {
        expect(
          gasVolume(
            tankSizeLiters: 12,
            pressureBar: 0,
            o2Percent: 21,
            model: model,
          ),
          0.0,
        );
        expect(
          gasVolume(
            tankSizeLiters: 12,
            pressureBar: -10,
            o2Percent: 21,
            model: model,
          ),
          0.0,
        );
      }
    });
  });

  group('pressureAfterConsuming honors the gas model', () {
    test('ideal model is the closed-form pressure drop', () {
      expect(
        pressureAfterConsuming(
          tankSizeLiters: 11.1,
          startPressureBar: 207,
          litersConsumed: 500,
          o2Percent: 21,
          model: GasModel.ideal,
        ),
        closeTo(207 - 500 / 11.1, 1e-9),
      );
    });

    test('real model needs more pressure for the same gas', () {
      final ideal = pressureAfterConsuming(
        tankSizeLiters: 11.1,
        startPressureBar: 207,
        litersConsumed: 500,
        o2Percent: 21,
        model: GasModel.ideal,
      );
      final real = pressureAfterConsuming(
        tankSizeLiters: 11.1,
        startPressureBar: 207,
        litersConsumed: 500,
        o2Percent: 21,
        model: GasModel.real,
      );
      // Real gas is less dense than ideal predicts at 200 bar, so delivering
      // the same 500 L costs more pressure and leaves less behind.
      expect(real, lessThan(ideal));
      expect(real, closeTo(155.94, 0.05));
    });

    test('round-trips with gasVolume under both models', () {
      const consumed = 800.0;
      for (final model in GasModel.values) {
        final end = pressureAfterConsuming(
          tankSizeLiters: 12.0,
          startPressureBar: 232,
          litersConsumed: consumed,
          o2Percent: 18,
          hePercent: 45,
          model: model,
        );
        final startVol = gasVolume(
          tankSizeLiters: 12.0,
          pressureBar: 232,
          o2Percent: 18,
          hePercent: 45,
          model: model,
        );
        final endVol = gasVolume(
          tankSizeLiters: 12.0,
          pressureBar: end,
          o2Percent: 18,
          hePercent: 45,
          model: model,
        );
        expect(startVol - endVol, closeTo(consumed, 0.5));
      }
    });

    test('pressureHoldingVolume inverts gasVolume under both models', () {
      for (final model in GasModel.values) {
        final bar = pressureHoldingVolume(
          tankSizeLiters: 11.1,
          litersRequired: 600,
          o2Percent: 21,
          model: model,
        );
        expect(
          gasVolume(
            tankSizeLiters: 11.1,
            pressureBar: bar,
            o2Percent: 21,
            model: model,
          ),
          closeTo(600, 0.5),
        );
      }
    });

    test('a reserve costs slightly less pressure under the real model', () {
      // Air's Z dips BELOW 1 up to about 121 bar and only rises above it at
      // fill pressures. So at a rock-bottom reserve of ~54 bar the cylinder
      // holds a little more gas than the ideal law predicts, and the reserve
      // pressure comes out marginally lower -- the opposite direction from
      // the same correction's effect on a full cylinder.
      final ideal = pressureHoldingVolume(
        tankSizeLiters: 11.1,
        litersRequired: 600,
        o2Percent: 21,
        model: GasModel.ideal,
      );
      final real = pressureHoldingVolume(
        tankSizeLiters: 11.1,
        litersRequired: 600,
        o2Percent: 21,
        model: GasModel.real,
      );
      expect(ideal, closeTo(600 / 11.1, 1e-9));
      expect(real, lessThan(ideal));
      // Under 1% apart: the correction is real but small at reserve pressures.
      expect(real, closeTo(ideal, ideal * 0.01));
    });

    test('the models cross over where air Z passes through 1', () {
      // Below ~121 bar real air is denser than ideal, above it thinner. A
      // model switch therefore moves numbers in opposite directions depending
      // on the pressure involved, which is why the preference has to apply
      // everywhere at once rather than per-screen.
      double barFor(double liters, GasModel model) => pressureHoldingVolume(
        tankSizeLiters: 12,
        litersRequired: liters,
        o2Percent: 21,
        model: model,
      );
      expect(barFor(600, GasModel.real), lessThan(barFor(600, GasModel.ideal)));
      expect(
        barFor(2400, GasModel.real),
        greaterThan(barFor(2400, GasModel.ideal)),
      );
    });

    test('pressureHoldingVolume returns 0 for a non-positive demand', () {
      for (final model in GasModel.values) {
        expect(
          pressureHoldingVolume(
            tankSizeLiters: 11.1,
            litersRequired: 0,
            o2Percent: 21,
            model: model,
          ),
          0.0,
        );
      }
    });

    test('consuming more than the cylinder holds returns 0', () {
      for (final model in GasModel.values) {
        expect(
          pressureAfterConsuming(
            tankSizeLiters: 11.1,
            startPressureBar: 207,
            litersConsumed: 99999,
            o2Percent: 21,
            model: model,
          ),
          0.0,
        );
      }
    });
  });
}
