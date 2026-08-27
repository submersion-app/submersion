import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The gas model preference (issue #828).
void main() {
  group('GasModel.fromName', () {
    test('round-trips every value through its stored name', () {
      for (final model in GasModel.values) {
        expect(GasModel.fromName(model.name), model);
      }
    });

    test('falls back to real gas for unknown or missing stored values', () {
      // An unreadable setting must never silently switch a diver's gas math
      // to the other model; it lands on the app default.
      expect(GasModel.fromName(null), GasModel.real);
      expect(GasModel.fromName(''), GasModel.real);
      expect(GasModel.fromName('vanderwaals'), GasModel.real);
    });
  });

  group('AppSettings.gasModel', () {
    test('defaults to real gas, preserving pre-#828 behavior', () {
      expect(const AppSettings().gasModel, GasModel.real);
    });

    test('copyWith carries the model through', () {
      const settings = AppSettings();
      expect(
        settings.copyWith(gasModel: GasModel.ideal).gasModel,
        GasModel.ideal,
      );
    });

    test('copyWith without the argument leaves the model alone', () {
      const settings = AppSettings(gasModel: GasModel.ideal);
      expect(settings.copyWith().gasModel, GasModel.ideal);
    });
  });
}
