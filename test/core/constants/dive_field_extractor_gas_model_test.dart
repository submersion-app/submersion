import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The SAC column honors the gas model preference (issue #828).
///
/// The volumetric lane is the only one that can differ: bar/min is a pressure
/// drop and carries no equation of state.
void main() {
  final dive = Dive(
    id: 'dive-828',
    dateTime: DateTime(2026, 8, 4, 10),
    runtime: const Duration(minutes: 44),
    avgDepth: 13.2,
    tanks: const [
      DiveTank(
        id: 'tank-1',
        volume: 12.0,
        startPressure: 200.0,
        endPressure: 50.0,
        gasMix: GasMix(o2: 21.0, he: 0.0),
        role: TankRole.backGas,
      ),
    ],
  );

  group('DiveField.sacRate under each gas model', () {
    test('L/min follows the ideal model when selected', () {
      final value = DiveField.sacRate.extractFromDive(
        dive,
        sacUnit: SacUnit.litersPerMin,
        gasModel: GasModel.ideal,
      );
      expect(value as double, closeTo(17.63, 0.01));
    });

    test('L/min follows the real model when selected', () {
      final value = DiveField.sacRate.extractFromDive(
        dive,
        sacUnit: SacUnit.litersPerMin,
        gasModel: GasModel.real,
      );
      expect(value as double, closeTo(16.77, 0.01));
    });

    test('bar/min is identical under both models', () {
      final ideal = DiveField.sacRate.extractFromDive(
        dive,
        sacUnit: SacUnit.pressurePerMin,
        gasModel: GasModel.ideal,
      );
      final real = DiveField.sacRate.extractFromDive(
        dive,
        sacUnit: SacUnit.pressurePerMin,
        gasModel: GasModel.real,
      );
      expect(ideal as double, closeTo(real as double, 1e-12));
    });

    test('the model does not leak into unrelated fields', () {
      for (final model in GasModel.values) {
        expect(DiveField.avgDepth.extractFromDive(dive, gasModel: model), 13.2);
      }
    });
  });
}
