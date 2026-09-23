import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_row_values.dart';

void main() {
  group('parseDivingLogCoordinate', () {
    test('reads the degrees minutes seconds form the real file uses', () {
      // 19 deg 38' 27.80" N = 19 + 38/60 + 27.80/3600
      expect(
        parseDivingLogCoordinate('19°38\'27.80"N'),
        closeTo(19 + 38 / 60 + 27.80 / 3600, 1e-9),
      );
    });

    test('negates the southern and western hemispheres', () {
      expect(
        parseDivingLogCoordinate('16°27\'59.74"S'),
        closeTo(-(16 + 27 / 60 + 59.74 / 3600), 1e-9),
      );
      expect(
        parseDivingLogCoordinate('156°0\'31.98"W'),
        closeTo(-(156 + 0 / 60 + 31.98 / 3600), 1e-9),
      );
    });

    test('keeps the northern and eastern hemispheres positive', () {
      expect(
        parseDivingLogCoordinate('145°58\'59.96"E'),
        closeTo(145 + 58 / 60 + 59.96 / 3600, 1e-9),
      );
    });

    test('accepts a plain decimal, which other versions may store', () {
      expect(parseDivingLogCoordinate('12.13'), closeTo(12.13, 1e-9));
      expect(parseDivingLogCoordinate('-68.28'), closeTo(-68.28, 1e-9));
    });

    test('rejects minutes or seconds outside their range', () {
      // 99 minutes is not a coordinate. Folding it in silently yields a
      // plausible looking 20.65 that the outer 180 check cannot catch.
      expect(parseDivingLogCoordinate('19°99\'0.00"N'), isNull);
      expect(parseDivingLogCoordinate('19°30\'99.00"N'), isNull);
      expect(
        parseDivingLogCoordinate('19°59\'59.99"N'),
        closeTo(19 + 59 / 60 + 59.99 / 3600, 1e-9),
      );
    });

    test('rejects a non-finite value', () {
      // double.tryParse accepts these, and NaN defeats the range check
      // because every NaN comparison is false. A NaN latitude would then
      // evade downstream validation for the same reason.
      expect(parseDivingLogCoordinate('NaN'), isNull);
      expect(parseDivingLogCoordinate('Infinity'), isNull);
      expect(parseDivingLogCoordinate('-Infinity'), isNull);
    });

    test('returns null for null, blank and unreadable text', () {
      expect(parseDivingLogCoordinate(null), isNull);
      expect(parseDivingLogCoordinate(''), isNull);
      expect(parseDivingLogCoordinate('somewhere nice'), isNull);
    });

    test('rejects a value outside the range any coordinate can take', () {
      // The parser is not told whether it is reading a latitude or a
      // longitude, so plus or minus 180 is the only bound it can apply.
      // Anything beyond that is not a coordinate at all.
      expect(parseDivingLogCoordinate('200.5'), isNull);
      expect(parseDivingLogCoordinate('181°0\'0.00"E'), isNull);
      // 91 is out of range for a latitude but valid for a longitude, so it
      // is kept: rejecting it here would lose real data.
      expect(parseDivingLogCoordinate('91.0'), closeTo(91.0, 1e-9));
    });
  });
}
