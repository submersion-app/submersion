import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';

void main() {
  group('SiteMatchSensitivity', () {
    test('balanced preset thresholds', () {
      final t = SiteMatchSensitivity.balanced.thresholds;
      expect(t.innerRadiusMeters, 150);
      expect(t.outerRadiusMeters, 1000);
      expect(t.separationMeters, 75);
    });

    test('strict is tighter than relaxed', () {
      expect(
        SiteMatchSensitivity.strict.thresholds.innerRadiusMeters,
        lessThan(SiteMatchSensitivity.relaxed.thresholds.innerRadiusMeters),
      );
    });

    test('fromName falls back to balanced for unknown', () {
      expect(
        SiteMatchSensitivity.fromName('nonsense'),
        SiteMatchSensitivity.balanced,
      );
      expect(
        SiteMatchSensitivity.fromName('strict'),
        SiteMatchSensitivity.strict,
      );
    });
  });
}
