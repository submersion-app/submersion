import 'package:flutter_test/flutter_test.dart';

import 'safety_review_fixtures.dart';

/// The safety-rule fixtures pin down specific ascent rates, so a segment that
/// silently spans a different number of seconds than it reads as would change
/// what those tests assert without changing what they say.
void main() {
  group('profile builders', () {
    test('emit one sample per interval and hit each segment target', () {
      final profile = buildFineProfile([(6, 60), (6, 20)]);

      expect(profile.timestamps.first, 0);
      expect(profile.timestamps.last, 80);
      expect(profile.timestamps, hasLength(41));
      expect(profile.depths.last, closeTo(6, 0.001));
    });

    test('reject a duration that is not a whole number of intervals', () {
      expect(
        () => buildFineProfile([(10, 19)]),
        throwsA(isA<AssertionError>()),
      );
      expect(() => buildProfile([(10, 25)]), throwsA(isA<AssertionError>()));
    });

    test('reject a duration shorter than one interval', () {
      // Truncation to zero steps would move the diver to the target depth
      // without emitting a single sample of the move.
      expect(() => buildFineProfile([(10, 1)]), throwsA(isA<AssertionError>()));
    });
  });
}
