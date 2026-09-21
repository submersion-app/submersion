import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_profile_codec.dart';

void main() {
  group('DivingLogProfileCodec.decode', () {
    test('decodes the documented Profile example', () {
      // 004500010000: 4.5 m, not in deco, ascending too fast.
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500010000',
      );
      expect(samples, hasLength(1));
      expect(samples.single.timeSeconds, 0);
      expect(samples.single.depthMeters, closeTo(4.5, 1e-9));
      expect(samples.single.inDeco, isFalse);
      expect(samples.single.ascentWarning, isTrue);
    });

    test('decodes the documented Profile2 example', () {
      // 25518051099: 25.5 C, 180.5 bar, tank 1, 99 min RBT.
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500010000',
        profile2: '25518051099',
      );
      final s = samples.single;
      expect(s.temperatureCelsius, closeTo(25.5, 1e-9));
      expect(s.pressureBar, closeTo(180.5, 1e-9));
      expect(s.tankId, 1);
      expect(s.rbtSeconds, 99 * 60);
    });

    test('spaces samples by the recording interval', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 30,
        profile:
            '004500010000'
            '010000000000'
            '015000000000',
      );
      expect(samples.map((s) => s.timeSeconds), [0, 30, 60]);
      expect(samples[1].depthMeters, closeTo(10.0, 1e-9));
      expect(samples[2].depthMeters, closeTo(15.0, 1e-9));
    });

    test('tolerates a short Profile2 that runs out before Profile', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile:
            '004500010000'
            '010000000000',
        profile2: '25518051099',
      );
      expect(samples, hasLength(2));
      expect(samples[0].temperatureCelsius, closeTo(25.5, 1e-9));
      expect(samples[1].temperatureCelsius, isNull);
    });

    test('reads deco, stop depth and tts from Profile and Profile4', () {
      // Profile flags deco at index 5; Profile4 is NNNSSSDDD.
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '030001000000',
        profile4: '012003006',
      );
      final s = samples.single;
      expect(s.inDeco, isTrue);
      expect(s.ttsSeconds, 12 * 60);
      expect(s.ndlSeconds, isNull);
      expect(s.stopDepthMeters, closeTo(6.0, 1e-9));
    });

    test('reads ndl from Profile4 when not in deco', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '030000000000',
        profile4: '025000000',
      );
      expect(samples.single.ndlSeconds, 25 * 60);
      expect(samples.single.ttsSeconds, isNull);
    });

    test('decodes the documented Profile5 example', () {
      // 1121131141548026411: 1.12/1.13/1.14 bar, OTU 154.8, CNS 26.4,
      // setpoint 1.1.
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500000000',
        profile5: '1121131141548026411',
      );
      final s = samples.single;
      expect(s.ppO2Cell1, closeTo(1.12, 1e-9));
      expect(s.ppO2Cell2, closeTo(1.13, 1e-9));
      expect(s.ppO2Cell3, closeTo(1.14, 1e-9));
      expect(s.otu, closeTo(154.8, 1e-9));
      expect(s.cns, closeTo(26.4, 1e-9));
      expect(s.setpoint, closeTo(1.1, 1e-9));
    });

    test('reads heart rate from Profile3', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500000000',
        profile3: '00000000072000',
      );
      expect(samples.single.heartRate, 72);
    });

    test('treats zero-padded Profile5 fields as absent', () {
      // The real export writes 0230000000000000000 on open-circuit dives:
      // one calculated ppO2 and the rest padding. Emitting those zeros as
      // readings would give the dive three O2 cells and a setpoint.
      final s = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500000000',
        profile5: '0230000000000000000',
      ).single;
      expect(s.ppO2Cell1, closeTo(0.23, 1e-9));
      expect(s.ppO2Cell2, isNull);
      expect(s.ppO2Cell3, isNull);
      expect(s.setpoint, isNull);
      expect(s.otu, isNull);
      expect(s.cns, isNull);
    });

    test('treats a zero stop depth as no ceiling', () {
      final s = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500000000',
        profile4: '000000000',
      ).single;
      expect(s.stopDepthMeters, isNull);
    });

    test('still decodes a genuine multi-cell sample', () {
      final s = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500000000',
        profile5: '1121131141548026411',
      ).single;
      expect(s.ppO2Cell1, closeTo(1.12, 1e-9));
      expect(s.ppO2Cell2, closeTo(1.13, 1e-9));
      expect(s.ppO2Cell3, closeTo(1.14, 1e-9));
      expect(s.setpoint, closeTo(1.1, 1e-9));
    });

    test('drops a sample whose depth cannot be read', () {
      // Blank depth is padding, not a surface sample; keeping it would draw
      // a spike to the surface mid-dive.
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile:
            '010000000000'
            '     0000000'
            '015000000000',
      );
      expect(samples, hasLength(2));
      expect(samples[0].depthMeters, closeTo(10.0, 1e-9));
      // The dropped sample still consumed its slot, so timestamps hold.
      expect(samples[1].timeSeconds, 40);
      expect(samples[1].depthMeters, closeTo(15.0, 1e-9));
    });

    test('returns no samples for a null or empty profile', () {
      expect(DivingLogProfileCodec.decode(intervalSeconds: 20), isEmpty);
      expect(
        DivingLogProfileCodec.decode(intervalSeconds: 20, profile: ''),
        isEmpty,
      );
    });

    test('ignores a trailing partial record', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile:
            '004500000000'
            '0100',
      );
      expect(samples, hasLength(1));
    });

    test('falls back to a one second interval when the interval is zero', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 0,
        profile:
            '004500000000'
            '010000000000',
      );
      expect(samples.map((s) => s.timeSeconds), [0, 1]);
    });
  });
}
