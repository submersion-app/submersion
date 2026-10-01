import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/deco_type.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

/// libdivecomputer reports a sample's deco state as NDL (0), safety stop (1),
/// deco stop (2) or deep stop (3). Only the last two are stops the computer
/// requires, so only they carry a ceiling (#2550).
void main() {
  group('decoStopCeiling', () {
    test('a deco stop and a deep stop carry their stop depth', () {
      expect(decoStopCeiling(kDecoTypeDecoStop, 6.0), 6.0);
      expect(decoStopCeiling(kDecoTypeDeepStop, 18.0), 18.0);
    });

    test('a safety stop carries no ceiling, whatever depth it reports', () {
      expect(decoStopCeiling(kDecoTypeSafetyStop, 5.0), isNull);
    });

    test('NDL and an unknown or missing state carry no ceiling', () {
      expect(decoStopCeiling(kDecoTypeNdl, 0.0), isNull);
      expect(decoStopCeiling(null, 6.0), isNull);
      expect(decoStopCeiling(7, 6.0), isNull);
    });

    test('a stop with no depth carries no ceiling', () {
      expect(decoStopCeiling(kDecoTypeDecoStop, null), isNull);
    });
  });

  group('ProfileSample.withoutSafetyStopCeiling', () {
    test('drops the ceiling of a safety stop sample and keeps the rest', () {
      const sample = ProfileSample(
        timestamp: 300,
        depth: 5.0,
        temperature: 24.0,
        ceiling: 5.0,
        tts: 0,
        decoType: kDecoTypeSafetyStop,
      );
      expect(
        sample.withoutSafetyStopCeiling(),
        const ProfileSample(
          timestamp: 300,
          depth: 5.0,
          temperature: 24.0,
          tts: 0,
          decoType: kDecoTypeSafetyStop,
        ),
      );
    });

    test('returns every other sample unchanged', () {
      const deco = ProfileSample(
        timestamp: 60,
        depth: 20.0,
        ceiling: 6.0,
        decoType: kDecoTypeDecoStop,
      );
      const untyped = ProfileSample(timestamp: 90, depth: 9.0, ceiling: 3.0);
      expect(identical(deco.withoutSafetyStopCeiling(), deco), isTrue);
      expect(identical(untyped.withoutSafetyStopCeiling(), untyped), isTrue);
    });
  });
}
