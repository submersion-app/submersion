import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/profile_lookup.dart';

void main() {
  group('ProfileLookup.interpolate', () {
    final lookup = ProfileLookup([0.0, 10.0, 20.0]);

    test('interpolates linearly between samples', () {
      expect(lookup.interpolate([0.0, 10.0, 20.0], 5), closeTo(5.0, 1e-9));
      expect(lookup.interpolate([0.0, 10.0, 20.0], 15), closeTo(15.0, 1e-9));
    });

    test('clamps outside the sampled range', () {
      expect(lookup.interpolate([1.0, 2.0, 3.0], -5), 1.0);
      expect(lookup.interpolate([1.0, 2.0, 3.0], 99), 3.0);
    });

    test('returns null when either neighbor is null', () {
      expect(lookup.interpolate([1.0, null, 3.0], 5), isNull);
      expect(lookup.interpolate([1.0, 2.0, null], 15), isNull);
    });
  });
}
