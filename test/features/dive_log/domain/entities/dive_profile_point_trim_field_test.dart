import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/deco_type.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample_point.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #5098: the trim angle a dive computer logs, on a profile point and
/// on the codec's sample, through every helper that rebuilds a sample.
void main() {
  group('DiveProfilePoint trim', () {
    test('defaults to null', () {
      const point = DiveProfilePoint(timestamp: 0, depth: 10.0);
      expect(point.trim, isNull);
    });

    test('takes part in equality and copyWith', () {
      const a = DiveProfilePoint(timestamp: 60, depth: 20.0, trim: -13.0);
      const b = DiveProfilePoint(timestamp: 60, depth: 20.0, trim: -13.0);
      expect(a, b);
      expect(a, isNot(a.copyWith(trim: 5.0)));
      expect(a.copyWith(depth: 21.0).trim, -13.0);
      expect(a.copyWith(trim: 5.0).trim, 5.0);
    });
  });

  group('ProfileSample trim', () {
    const sample = ProfileSample(
      timestamp: 30,
      depth: 12.0,
      ceiling: 3.0,
      decoType: kDecoTypeSafetyStop,
      gf99: 40,
      aveloBuoyancy: -0.393,
      trim: -13.0,
    );

    test('shiftedBy keeps it', () {
      expect(sample.shiftedBy(10).trim, -13.0);
    });

    test('withTissue keeps it', () {
      expect(sample.withTissue(gf99: 50).trim, -13.0);
    });

    test('withAvelo keeps it', () {
      expect(sample.withAvelo(computerRmv: 12.0).trim, -13.0);
    });

    test('withoutSafetyStopCeiling keeps it', () {
      final scrubbed = sample.withoutSafetyStopCeiling();
      expect(scrubbed.ceiling, isNull);
      expect(scrubbed.trim, -13.0);
    });

    test('withTrim sets exactly that trim and keeps the rest', () {
      final moved = sample.withTrim(trim: 87.0);
      expect(moved.trim, 87.0);
      expect(moved.aveloBuoyancy, -0.393);
      expect(moved.gf99, 40);
      expect(sample.withTrim().trim, isNull);
    });

    test('takes part in equality', () {
      expect(sample, isNot(sample.withTrim(trim: 5.0)));
    });

    test('converts to and from a profile point', () {
      final point = sample.toPoint();
      expect(point.trim, -13.0);
      expect(profileSampleFromPoint(point).trim, -13.0);
    });
  });
}
