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

    test('carries every other field across (the v255 rewrite must lose '
        'nothing)', () {
      const full = ProfileSample(
        timestamp: 300,
        depth: 5.0,
        pressure: 150.0,
        temperature: 24.0,
        heartRate: 80,
        ascentRate: -3.0,
        // Distinct from every other value, so indexOf finds this field.
        ceiling: 4.5,
        ndl: 1800,
        setpoint: 1.2,
        ppO2: 1.19,
        o2Sensor1: 1.18,
        o2Sensor2: 1.2,
        o2Sensor3: 1.21,
        o2Sensor4: 1.17,
        o2Sensor5: 1.22,
        o2Sensor6: 1.19,
        cns: 12.5,
        tts: 0,
        rbt: 1500,
        decoType: kDecoTypeSafetyStop,
        heartRateSource: 'appleWatch',
        heading: 270.0,
        o2SensorMv1: 51,
        o2SensorMv2: 52,
        o2SensorMv3: 53,
        o2SensorMv4: 50,
        o2SensorMv5: 54,
        o2SensorMv6: 52,
      );
      // A field added to ProfileSample but left null here fails this line,
      // which forces the fixture (and the method) to be brought up to date.
      expect(full.props.where((p) => p == null), isEmpty);

      final scrubbed = full.withoutSafetyStopCeiling();
      final ceilingAt = full.props.indexOf(full.ceiling);
      expect(scrubbed.props, [
        for (var i = 0; i < full.props.length; i++)
          i == ceilingAt ? null : full.props[i],
      ]);
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
