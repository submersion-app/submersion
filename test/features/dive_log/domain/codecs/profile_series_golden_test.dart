import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

/// Freezes the codecs' v1 wire format.
///
/// These golden bodies are captured once from a known-good encode and pasted
/// in as literals. They exist so a reordered field table or a changed delta
/// convention fails a test even though round trips through the same codec
/// stay green: a round trip alone cannot tell a stable format from a
/// silently-changed one, because it always decodes with the same encoder
/// that wrote it.
///
/// A future change that alters a golden body is a codec version bump, never
/// an edit to the literal.
void main() {
  const codec = ProfileSeriesCodec();
  const tankCodec = TankPressureSeriesCodec();

  Uint8List inflate(Uint8List bytes) => Uint8List.fromList(zlib.decode(bytes));

  Uint8List recompress(List<int> body) =>
      Uint8List.fromList(ZLibCodec(level: 6).encode(body));

  const samples = [
    ProfileSample(
      timestamp: 0,
      depth: 1.5,
      pressure: 0.25,
      temperature: 0.5,
      heartRate: 1,
      ascentRate: 0.75,
      ceiling: 1.0,
      ndl: 2,
      setpoint: 1.25,
      ppO2: 1.75,
      o2Sensor1: 2.25,
      o2Sensor2: 2.75,
      o2Sensor3: 3.25,
      o2Sensor4: 3.75,
      o2Sensor5: 4.25,
      o2Sensor6: 4.75,
      cns: 5.25,
      tts: 3,
      rbt: 4,
      decoType: 5,
      heartRateSource: 'a',
      heading: 5.75,
      o2SensorMv1: 6,
      o2SensorMv2: 7,
      o2SensorMv3: 8,
      o2SensorMv4: 9,
      o2SensorMv5: 10,
      o2SensorMv6: 11,
    ),
    ProfileSample(
      timestamp: 10,
      depth: 2.5,
      pressure: 10.25,
      temperature: 10.5,
      heartRate: 101,
      ascentRate: 10.75,
      ceiling: 11.0,
      ndl: 102,
      setpoint: 11.25,
      ppO2: 11.75,
      o2Sensor1: 12.25,
      o2Sensor2: 12.75,
      o2Sensor3: 13.25,
      o2Sensor4: 13.75,
      o2Sensor5: 14.25,
      o2Sensor6: 14.75,
      cns: 15.25,
      tts: 103,
      rbt: 104,
      decoType: 105,
      heartRateSource: 'b',
      heading: 15.75,
      o2SensorMv1: 106,
      o2SensorMv2: 107,
      o2SensorMv3: 108,
      o2SensorMv4: 109,
      o2SensorMv5: 110,
      o2SensorMv6: 111,
    ),
  ];

  // Captured from a known-good encode of `samples` above. The first bytes,
  // hand-verified:
  //   [0]  1   version
  //   [1]  2   sample count
  //   [2]  1   timestamp presence mode (kPresenceAll)
  //   [3]  0   zigzag delta of timestamp 0 (0 - 0 = 0 -> 0)
  //   [4]  20  zigzag delta of timestamp 10 (10 - 0 = 10 -> 20)
  //   [5]  1   depth presence mode (kPresenceAll)
  //   [6..13]  00 00 00 00 00 00 F8 3F: float64 1.5, little-endian
  //   [14..21] 00 00 00 00 00 00 04 40: float64 2.5, little-endian
  // [22] onward is the pressure column (presence mode, then two float64s),
  // followed by the remaining 25 columns in field-table order.
  const goldenBody = <int>[
    1, 2, 1, 0, 20, 1, //
    0, 0, 0, 0, 0, 0, 248, 63, //
    0, 0, 0, 0, 0, 0, 4, 64, //
    1, //
    0, 0, 0, 0, 0, 0, 208, 63, //
    0, 0, 0, 0, 0, 128, 36, 64, //
    1, //
    0, 0, 0, 0, 0, 0, 224, 63, //
    0, 0, 0, 0, 0, 0, 37, 64, //
    1, 2, 200, 1, 1, //
    0, 0, 0, 0, 0, 0, 232, 63, //
    0, 0, 0, 0, 0, 128, 37, 64, //
    1, //
    0, 0, 0, 0, 0, 0, 240, 63, //
    0, 0, 0, 0, 0, 0, 38, 64, //
    1, 4, 200, 1, 1, //
    0, 0, 0, 0, 0, 0, 244, 63, //
    0, 0, 0, 0, 0, 128, 38, 64, //
    1, //
    0, 0, 0, 0, 0, 0, 252, 63, //
    0, 0, 0, 0, 0, 128, 39, 64, //
    1, //
    0, 0, 0, 0, 0, 0, 2, 64, //
    0, 0, 0, 0, 0, 128, 40, 64, //
    1, //
    0, 0, 0, 0, 0, 0, 6, 64, //
    0, 0, 0, 0, 0, 128, 41, 64, //
    1, //
    0, 0, 0, 0, 0, 0, 10, 64, //
    0, 0, 0, 0, 0, 128, 42, 64, //
    1, //
    0, 0, 0, 0, 0, 0, 14, 64, //
    0, 0, 0, 0, 0, 128, 43, 64, //
    1, //
    0, 0, 0, 0, 0, 0, 17, 64, //
    0, 0, 0, 0, 0, 128, 44, 64, //
    1, //
    0, 0, 0, 0, 0, 0, 19, 64, //
    0, 0, 0, 0, 0, 128, 45, 64, //
    1, //
    0, 0, 0, 0, 0, 0, 21, 64, //
    0, 0, 0, 0, 0, 128, 46, 64, //
    1, 6, 200, 1, 1, 8, 200, 1, 1, 10, 200, 1, //
    1, 2, 1, 1, 97, 1, 1, 98, //
    1, //
    0, 0, 0, 0, 0, 0, 23, 64, //
    0, 0, 0, 0, 0, 128, 47, 64, //
    1, 12, 200, 1, 1, 14, 200, 1, 1, 16, 200, 1, //
    1, 18, 200, 1, 1, 20, 200, 1, 1, 22, 200, 1,
  ];

  const tankSamples = [
    TankPressureSample(timestamp: 0, pressure: 200.0),
    TankPressureSample(timestamp: 10, pressure: 190.5),
    TankPressureSample(timestamp: 20, pressure: 181.0),
  ];

  // [1]        version
  // [3]        sample count
  // [1, 0, 20, 20]   timestamp: mode, then zigzag deltas 0, 10, 10
  // [1]        pressure presence mode
  // 24 bytes   three float64 pressures, little-endian
  const tankGoldenBody = <int>[
    1, 3, 1, 0, 20, 20, //
    1, //
    0, 0, 0, 0, 0, 0, 105, 64, //
    0, 0, 0, 0, 0, 208, 103, 64, //
    0, 0, 0, 0, 0, 160, 102, 64,
  ];

  group('profile series codec v1', () {
    test('encoding freezes to the golden body', () {
      final encoded = codec.encode(samples);
      expect(inflate(encoded.bytes), goldenBody);
    });

    test('the golden body decodes to the source samples', () {
      expect(codec.decode(recompress(goldenBody)), samples);
    });
  });

  group('tank pressure series codec v1', () {
    test('encoding freezes to the golden body', () {
      final encoded = tankCodec.encode(tankSamples);
      expect(inflate(encoded.bytes), tankGoldenBody);
    });

    test('the golden body decodes to the source samples', () {
      expect(tankCodec.decode(recompress(tankGoldenBody)), tankSamples);
    });
  });
}
