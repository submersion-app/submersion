import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';

void main() {
  group('TemperatureUnit.convertDelta', () {
    test('scales celsius deltas to fahrenheit without the offset', () {
      expect(
        TemperatureUnit.celsius.convertDelta(0.5, TemperatureUnit.fahrenheit),
        closeTo(0.9, 1e-9),
      );
      expect(
        TemperatureUnit.celsius.convertDelta(-1.0, TemperatureUnit.fahrenheit),
        closeTo(-1.8, 1e-9),
      );
    });

    test('is identity for same-unit conversion', () {
      expect(
        TemperatureUnit.celsius.convertDelta(0.7, TemperatureUnit.celsius),
        closeTo(0.7, 1e-9),
      );
    });

    test('scales fahrenheit deltas back to celsius', () {
      expect(
        TemperatureUnit.fahrenheit.convertDelta(1.8, TemperatureUnit.celsius),
        closeTo(1.0, 1e-9),
      );
    });
  });
}
