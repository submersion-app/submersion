import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance.dart';

/// One dive's vertical distance (issue #4569): metres travelled down, which
/// equals metres travelled up because every dive starts and ends at the
/// surface. Each expected value below is worked out by hand from the
/// turning points, not read back from the implementation.
void main() {
  group('verticalDistanceMeters', () {
    test('a simple dive counts its max depth', () {
      // Down to 20, back up: one descent of 20.
      expect(verticalDistanceMeters([0, 5, 12, 20, 20, 14, 6, 0]), 20);
    });

    test('a multi-level dive counts the second descent', () {
      // 0 -> 30 (30), up to 12, down to 18 (6), up to 0. 30 + 6.
      expect(verticalDistanceMeters([0, 30, 12, 18, 0]), 36);
    });

    test('a sawtooth under the deadband adds nothing', () {
      // Every rise is under 1 m, so no reversal is ever confirmed.
      expect(verticalDistanceMeters([0, 20, 19.5, 20, 19.4, 20, 0]), 20);
    });

    test('a sawtooth over the deadband counts each descent', () {
      // 20, then 18 -> 20 twice: 20 + 2 + 2.
      expect(verticalDistanceMeters([0, 20, 18, 20, 18, 20, 0]), 24);
    });

    test('a dip under the deadband does not split a descent', () {
      // The 0.8 m rise at 19.2 is noise; the descent carries on to 20.5.
      expect(verticalDistanceMeters([0, 20, 19.2, 20.5, 0]), 20.5);
    });

    test(
      'a profile that starts and ends at depth is counted from the surface',
      () {
        // Surface -> 5 -> 20 is one descent of 20; 20 -> 3 -> surface is
        // the ascent back.
        expect(verticalDistanceMeters([5, 20, 3]), 20);
      },
    );

    test('a reversal of exactly the deadband counts', () {
      // 10, up exactly 1 m to 9, down to 10 again: 10 + 1.
      expect(verticalDistanceMeters([0, 10, 9, 10, 0]), 11);
    });

    test('a dive shallower than the deadband still counts', () {
      // The surface at the end is a turning point whatever the deadband.
      expect(verticalDistanceMeters([0.2, 0.5, 0.3]), 0.5);
    });

    test('one sample counts its depth', () {
      expect(verticalDistanceMeters([12]), 12);
    });

    test('no samples count nothing', () {
      expect(verticalDistanceMeters(const []), 0);
    });

    test('non-finite and negative depths are skipped', () {
      expect(
        verticalDistanceMeters([0, double.nan, 10, -3, double.infinity, 10, 0]),
        10,
      );
    });

    test('the deadband is a parameter', () {
      // With a 3 m deadband the 2 m rises in the sawtooth are noise.
      expect(
        verticalDistanceMeters([0, 20, 18, 20, 18, 20, 0], deadband: 3),
        20,
      );
    });
  });
}
