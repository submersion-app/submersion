import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';

void main() {
  group('VisibilityScale.bandFor', () {
    test('tropical preset reproduces the pre-v144 thresholds', () {
      const scale = VisibilityScale.tropical;
      expect(scale.bandFor(31), VisibilityBand.excellent);
      expect(scale.bandFor(20), VisibilityBand.good);
      expect(scale.bandFor(10), VisibilityBand.moderate);
      expect(scale.bandFor(2), VisibilityBand.poor);
    });

    test('boundaries are inclusive at the lower edge', () {
      const scale = VisibilityScale.tropical;
      expect(scale.bandFor(30), VisibilityBand.excellent);
      expect(scale.bandFor(29.99), VisibilityBand.good);
      expect(scale.bandFor(15), VisibilityBand.good);
      expect(scale.bandFor(14.99), VisibilityBand.moderate);
      expect(scale.bandFor(5), VisibilityBand.moderate);
      expect(scale.bandFor(4.99), VisibilityBand.poor);
    });

    test('cold-water preset calls a 6 m day good and a 12 m day excellent', () {
      const scale = VisibilityScale.coldWater;
      expect(scale.bandFor(6), VisibilityBand.good);
      expect(scale.bandFor(12), VisibilityBand.excellent);
      expect(scale.bandFor(1.5), VisibilityBand.poor);
    });

    test('temperate preset sits between tropical and cold water', () {
      const scale = VisibilityScale.temperate;
      expect(scale.bandFor(20), VisibilityBand.excellent);
      expect(scale.bandFor(10), VisibilityBand.good);
      expect(scale.bandFor(4), VisibilityBand.moderate);
      expect(scale.bandFor(3.99), VisibilityBand.poor);
    });

    test('zero and negative distances are poor, not a crash', () {
      expect(VisibilityScale.tropical.bandFor(0), VisibilityBand.poor);
      expect(VisibilityScale.tropical.bandFor(-1), VisibilityBand.poor);
    });
  });

  group('VisibilityScale.forPreset', () {
    test('named presets ignore the custom values', () {
      final scale = VisibilityScale.forPreset(
        VisibilityScalePreset.coldWater,
        excellentM: 99,
        goodM: 88,
        moderateM: 77,
      );
      expect(scale, VisibilityScale.coldWater);
    });

    test('custom uses supplied values', () {
      final scale = VisibilityScale.forPreset(
        VisibilityScalePreset.custom,
        excellentM: 18,
        goodM: 9,
        moderateM: 3,
      );
      expect(scale.bandFor(18), VisibilityBand.excellent);
      expect(scale.bandFor(9), VisibilityBand.good);
      expect(scale.bandFor(3), VisibilityBand.moderate);
      expect(scale.bandFor(2.99), VisibilityBand.poor);
    });

    test('custom falls back to tropical when values are missing', () {
      expect(
        VisibilityScale.forPreset(VisibilityScalePreset.custom),
        VisibilityScale.tropical,
      );
      expect(
        VisibilityScale.forPreset(
          VisibilityScalePreset.custom,
          excellentM: 18,
          goodM: 9,
        ),
        VisibilityScale.tropical,
      );
    });

    test('custom falls back to tropical when values are invalid', () {
      final scale = VisibilityScale.forPreset(
        VisibilityScalePreset.custom,
        excellentM: 5,
        goodM: 10,
        moderateM: 20,
      );
      expect(scale, VisibilityScale.tropical);
    });
  });

  group('VisibilityScale.isValid', () {
    test('accepts strictly descending positive thresholds', () {
      expect(
        const VisibilityScale(
          excellentAtOrAboveM: 12,
          goodAtOrAboveM: 6,
          moderateAtOrAboveM: 2,
        ).isValid,
        isTrue,
      );
    });

    test('rejects equal adjacent thresholds', () {
      expect(
        const VisibilityScale(
          excellentAtOrAboveM: 6,
          goodAtOrAboveM: 6,
          moderateAtOrAboveM: 2,
        ).isValid,
        isFalse,
      );
    });

    test('rejects a non-positive lowest threshold', () {
      expect(
        const VisibilityScale(
          excellentAtOrAboveM: 12,
          goodAtOrAboveM: 6,
          moderateAtOrAboveM: 0,
        ).isValid,
        isFalse,
      );
    });

    test('all shipped presets are valid', () {
      expect(VisibilityScale.tropical.isValid, isTrue);
      expect(VisibilityScale.temperate.isValid, isTrue);
      expect(VisibilityScale.coldWater.isValid, isTrue);
    });
  });

  group('VisibilityScale.toString', () {
    test('names all three thresholds for debugging', () {
      final text = VisibilityScale.coldWater.toString();
      expect(text, contains('12'));
      expect(text, contains('6'));
      expect(text, contains('2'));
    });
  });

  group('VisibilityScale equality', () {
    test('differs from a non-scale value', () {
      expect(VisibilityScale.tropical == Object(), isFalse);
    });

    test('scales with identical thresholds are equal', () {
      const a = VisibilityScale(
        excellentAtOrAboveM: 30,
        goodAtOrAboveM: 15,
        moderateAtOrAboveM: 5,
      );
      expect(a, VisibilityScale.tropical);
      expect(a.hashCode, VisibilityScale.tropical.hashCode);
    });

    test('scales with different thresholds are not equal', () {
      expect(VisibilityScale.coldWater, isNot(VisibilityScale.tropical));
    });
  });
}
