import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_units.dart';

void main() {
  group('Dl7Units.fromZrh', () {
    test('parses a metric ZRH (real DiverLog+ header)', () {
      final units = Dl7Units.fromZrh(
        'ZRH|^~<>{}||13960|MSWG|ThM|C|BAR|L|'.split('|'),
      );
      expect(units.depthIsFeet, isFalse);
      expect(units.tempIsFahrenheit, isFalse);
      expect(units.pressureIsPsi, isFalse);
      expect(units.volumeIsCubicFeet, isFalse);
    });

    test('parses an imperial ZRH (spec-style header)', () {
      final units = Dl7Units.fromZrh(
        'ZRH|^~<>{}|NEM001|SC02201|FSWG|ThFt|F|PSIA|CF|'.split('|'),
      );
      expect(units.depthIsFeet, isTrue);
      expect(units.tempIsFahrenheit, isTrue);
      expect(units.pressureIsPsi, isTrue);
      expect(units.volumeIsCubicFeet, isTrue);
    });

    test('treats MFWG as metric and lowercase bar as bar', () {
      final units = Dl7Units.fromZrh(
        'ZRH|^~\\&{}|||MFWG|ThM|C|bar|L|'.split('|'),
      );
      expect(units.depthIsFeet, isFalse);
      expect(units.pressureIsPsi, isFalse);
    });

    test('defaults to metric when ZRH is missing or short', () {
      final units = Dl7Units.fromZrh(const []);
      expect(units.depthIsFeet, isFalse);
      expect(units.tempIsFahrenheit, isFalse);
      expect(units.pressureIsPsi, isFalse);
      expect(units.volumeIsCubicFeet, isFalse);
    });
  });

  group('conversions', () {
    const imperial = Dl7Units(
      depthIsFeet: true,
      tempIsFahrenheit: true,
      pressureIsPsi: true,
      volumeIsCubicFeet: true,
    );
    const metric = Dl7Units();

    test('depth feet to meters', () {
      expect(imperial.depthToMeters(60), closeTo(18.288, 0.001));
      expect(metric.depthToMeters(18.3), 18.3);
    });

    test('temperature fahrenheit to celsius', () {
      expect(imperial.tempToCelsius(80), closeTo(26.667, 0.001));
      expect(imperial.tempToCelsius(32), closeTo(0.0, 0.0001));
      expect(metric.tempToCelsius(27.2), 27.2);
    });

    test('pressure psi to bar', () {
      expect(imperial.pressureToBar(3000), closeTo(206.843, 0.001));
      expect(metric.pressureToBar(200), 200);
    });
  });
}
