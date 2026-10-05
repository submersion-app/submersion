import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const celsius = UnitFormatter(
    AppSettings(temperatureUnit: TemperatureUnit.celsius),
  );
  const fahrenheit = UnitFormatter(
    AppSettings(temperatureUnit: TemperatureUnit.fahrenheit),
  );

  group('formatTemperature', () {
    test('keeps one decimal when it carries information', () {
      // The bug in #912: a logbook recorded at 78 F stores 25.5555... C, and
      // whole-degree Celsius rendered it as 26 C.
      expect(celsius.formatTemperature(25.5555), '25.6°C');
      expect(celsius.formatTemperature(22.4), '22.4°C');
    });

    test('drops a zero decimal rather than showing .0', () {
      expect(celsius.formatTemperature(26.0), '26°C');
      expect(celsius.formatTemperature(0.0), '0°C');
      expect(celsius.formatTemperature(-3.0), '-3°C');
    });

    test('rounds to one decimal before trimming', () {
      expect(celsius.formatTemperature(25.96), '26°C');
      expect(celsius.formatTemperature(25.04), '25°C');
    });

    test('applies the same rule after conversion to Fahrenheit', () {
      // 22 C is exactly 71.6 F - a real decimal, so it is kept.
      expect(fahrenheit.formatTemperature(22.0), '71.6°F');
      // 25.5555... C is 78.0 F, whose decimal is zero and so is dropped.
      expect(fahrenheit.formatTemperature(25.5555), '78°F');
    });

    test('honours an explicit decimals argument', () {
      expect(celsius.formatTemperature(25.5555, decimals: 2), '25.56°C');
      expect(celsius.formatTemperature(25.5555, decimals: 0), '26°C');
      // Trailing zeros are still trimmed at higher precision.
      expect(celsius.formatTemperature(26.0, decimals: 2), '26°C');
    });

    test('renders null as a placeholder', () {
      expect(celsius.formatTemperature(null), '--');
      expect(fahrenheit.formatTemperature(null), '--');
    });
  });

  group('formatTemperatureDelta', () {
    test('scales a Fahrenheit difference without the 32-degree offset', () {
      // 2 C warmer is 3.6 F warmer; as a reading 2 C would be 35.6 F.
      expect(fahrenheit.formatTemperatureDelta(2), '3.6°F');
    });

    test('leaves a Celsius difference as it is', () {
      expect(celsius.formatTemperatureDelta(1.7), '1.7°C');
      expect(celsius.formatTemperatureDelta(2), '2°C');
    });
  });
}
