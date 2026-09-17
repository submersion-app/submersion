import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_slot_count.dart';

void main() {
  group('phonePrimarySlotCount', () {
    test('never returns fewer than the minimum on a narrow phone', () {
      final count = phonePrimarySlotCount(
        baseWidth: 360,
        showLabels: true,
        availableCount: 14,
      );

      expect(count, kMinPhonePrimarySlotCount);
    });

    test('grows on a wider base width', () {
      final narrow = phonePrimarySlotCount(
        baseWidth: 360,
        showLabels: true,
        availableCount: 14,
      );
      final wide = phonePrimarySlotCount(
        baseWidth: 900,
        showLabels: true,
        availableCount: 14,
      );

      expect(wide, greaterThan(narrow));
    });

    test('hiding labels fits more slots in the same width', () {
      const width = 640.0;
      final withLabels = phonePrimarySlotCount(
        baseWidth: width,
        showLabels: true,
        availableCount: 14,
      );
      final iconOnly = phonePrimarySlotCount(
        baseWidth: width,
        showLabels: false,
        availableCount: 14,
      );

      expect(iconOnly, greaterThan(withLabels));
    });

    test('never exceeds the number of available destinations', () {
      final count = phonePrimarySlotCount(
        baseWidth: 4000,
        showLabels: false,
        availableCount: 5,
      );

      expect(count, 5);
    });

    test('the minimum never exceeds the number of available destinations', () {
      final count = phonePrimarySlotCount(
        baseWidth: 360,
        showLabels: true,
        availableCount: 2,
      );

      expect(count, 2);
    });

    test('a pure rotation does not change the result', () {
      // Portrait 400x800 and the same phone rotated to 800x400: min() picks
      // the same base width either way.
      final portrait = phonePrimarySlotCount(
        baseWidth: _baseWidth(400, 800),
        showLabels: true,
        availableCount: 14,
      );
      final landscape = phonePrimarySlotCount(
        baseWidth: _baseWidth(800, 400),
        showLabels: true,
        availableCount: 14,
      );

      expect(landscape, portrait);
    });

    test('an extremely narrow width still clamps to the minimum', () {
      final count = phonePrimarySlotCount(
        baseWidth: 0,
        showLabels: true,
        availableCount: 14,
      );

      expect(count, kMinPhonePrimarySlotCount);
    });
  });
}

double _baseWidth(double width, double height) =>
    width < height ? width : height;
