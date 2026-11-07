import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The RMV column honors the gas model preference (issue #828). SAC is a
/// pressure drop and carries no equation of state.
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

  group('DiveField.rmv under each gas model', () {
    test('follows the ideal model when selected', () {
      final value = DiveField.rmv.extractFromDive(
        dive,
        gasModel: GasModel.ideal,
      );
      expect(value as double, closeTo(17.63, 0.01));
    });

    test('follows the real model when selected', () {
      final value = DiveField.rmv.extractFromDive(
        dive,
        gasModel: GasModel.real,
      );
      expect(value as double, closeTo(16.77, 0.01));
    });
  });

  group('DiveField.sac', () {
    test('is identical under both models', () {
      final ideal = DiveField.sac.extractFromDive(
        dive,
        gasModel: GasModel.ideal,
      );
      final real = DiveField.sac.extractFromDive(dive, gasModel: GasModel.real);
      expect(ideal as double, closeTo(real as double, 1e-12));
    });

    test('the model does not leak into unrelated fields', () {
      for (final model in GasModel.values) {
        expect(DiveField.avgDepth.extractFromDive(dive, gasModel: model), 13.2);
      }
    });
  });

  // A suit inflation bottle listed first is not the dive's gas (#4243).
  group('a suit inflation bottle listed first', () {
    final withSuit = Dive(
      id: 'dive-4243',
      dateTime: DateTime(2026, 8, 4, 10),
      runtime: const Duration(minutes: 44),
      avgDepth: 13.2,
      tanks: [
        const DiveTank(
          id: 'suit',
          volume: 0.85,
          startPressure: 200.0,
          endPressure: 150.0,
          gasMix: GasMix(o2: 21.0),
          role: TankRole.suitInflation,
        ),
        dive.tanks.single.copyWith(gasMix: const GasMix(o2: 32.0)),
      ],
    );

    test('is not the primary gas or its pressures', () {
      expect(DiveField.primaryGas.extractFromDive(withSuit), 'EAN32');
      expect(DiveField.startPressure.extractFromDive(withSuit), 200.0);
      expect(DiveField.endPressure.extractFromDive(withSuit), 50.0);
    });

    test('adds no gas consumed', () {
      final onlyBreathing = withSuit.copyWith(tanks: [withSuit.tanks.last]);
      expect(
        DiveField.gasConsumed.extractFromDive(
          withSuit,
          gasModel: GasModel.ideal,
        ),
        DiveField.gasConsumed.extractFromDive(
          onlyBreathing,
          gasModel: GasModel.ideal,
        ),
      );
    });

    test('still counts as a cylinder carried', () {
      expect(DiveField.tankCount.extractFromDive(withSuit), 2);
    });
  });
}
