import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';

void main() {
  group('normalizeUddfTankVolumeToLiters (#158)', () {
    test('spec-conformant cubic meter values scale x1000', () {
      // UDDF 3.2.3 defines tankvolume in cubic meters.
      expect(normalizeUddfTankVolumeToLiters(0.0111), closeTo(11.1, 0.0001));
      expect(normalizeUddfTankVolumeToLiters(0.012), closeTo(12.0, 0.0001));
      expect(normalizeUddfTankVolumeToLiters(0.007), closeTo(7.0, 0.0001));
    });

    test('Diving Log 10x-off values scale x100', () {
      // Diving Log 6.x writes 0.111 for an 11.1 L tank (10x off from spec).
      expect(normalizeUddfTankVolumeToLiters(0.111), closeTo(11.1, 0.0001));
      expect(normalizeUddfTankVolumeToLiters(0.24), closeTo(24.0, 0.0001));
    });

    test('legacy liter-valued exports pass through unchanged', () {
      // Old Submersion exports (and other non-conforming tools) wrote liters.
      expect(normalizeUddfTankVolumeToLiters(2.0), closeTo(2.0, 0.0001));
      expect(normalizeUddfTankVolumeToLiters(11.1), closeTo(11.1, 0.0001));
      expect(normalizeUddfTankVolumeToLiters(24.0), closeTo(24.0, 0.0001));
    });

    test('implausible values pass through unchanged', () {
      expect(normalizeUddfTankVolumeToLiters(111.0), closeTo(111.0, 0.0001));
      expect(normalizeUddfTankVolumeToLiters(0.0), closeTo(0.0, 0.0001));
      expect(normalizeUddfTankVolumeToLiters(-1.0), closeTo(-1.0, 0.0001));
    });
  });
}
