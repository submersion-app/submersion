import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/surface_pressure.dart';

void main() {
  group('normalizeSurfacePressureBar', () {
    test('passes a normal sea-level value through unchanged', () {
      expect(normalizeSurfacePressureBar(1.013), 1.013);
    });

    test('keeps a valid high-altitude value', () {
      expect(normalizeSurfacePressureBar(0.75), 0.75);
    });

    test('null stays null', () {
      expect(normalizeSurfacePressureBar(null), isNull);
    });

    test('converts a millibar value into bar', () {
      expect(normalizeSurfacePressureBar(1013.0), closeTo(1.013, 1e-9));
    });

    test('converts a hectopascal value into bar', () {
      expect(normalizeSurfacePressureBar(1005.0), closeTo(1.005, 1e-9));
    });

    test('rejects an implausible value (mbar magnitude, out of range)', () {
      // 1264 -> 1.264 bar, still impossible as a surface pressure.
      expect(normalizeSurfacePressureBar(1264.0), isNull);
    });

    test('rejects a small-but-impossible value', () {
      expect(normalizeSurfacePressureBar(2.5), isNull);
      expect(normalizeSurfacePressureBar(0.1), isNull);
    });

    test('keeps the plausible boundaries', () {
      expect(normalizeSurfacePressureBar(0.5), 0.5);
      expect(normalizeSurfacePressureBar(1.1), 1.1);
    });
  });
}
