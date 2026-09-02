import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/bounded_inflate.dart';
import 'package:submersion/features/dive_log/domain/codecs/byte_io.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

void main() {
  const codec = TankPressureSeriesCodec();

  List<TankPressureSample> descending(int count) => [
    for (var i = 0; i < count; i++)
      TankPressureSample(timestamp: i * 10, pressure: 210.0 - i * 0.3),
  ];

  group('round trips', () {
    test('a typical series', () {
      final samples = descending(200);
      final encoded = codec.encode(samples);
      expect(encoded.codecVersion, 1);
      expect(codec.decode(encoded.bytes), samples);
    });

    test('a single sample', () {
      const samples = [TankPressureSample(timestamp: 0, pressure: 200.0)];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('duplicate timestamps survive in insertion order', () {
      const samples = [
        TankPressureSample(timestamp: 5, pressure: 200.0),
        TankPressureSample(timestamp: 5, pressure: 199.0),
        TankPressureSample(timestamp: 6, pressure: 198.5),
      ];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('pressures are bit-exact', () {
      const samples = [
        TankPressureSample(timestamp: 0, pressure: 0.1 + 0.2),
        TankPressureSample(timestamp: 1, pressure: 1e-300),
      ];
      final decoded = codec.decode(codec.encode(samples).bytes);
      expect(decoded[0].pressure, 0.1 + 0.2);
      expect(decoded[1].pressure, 1e-300);
    });

    test('20,000 samples pack below raw columnar size', () {
      final samples = descending(20000);
      final encoded = codec.encode(samples);
      expect(codec.decode(encoded.bytes), samples);
      // Raw columnar is one varint byte plus eight float bytes per sample.
      // Any compression at all lands below this; the bound is deterministic.
      expect(encoded.bytes.length, lessThan(20000 * 9));
    });
  });

  group('summary', () {
    test('encode returns the summary of the packed samples', () {
      final samples = descending(10);
      final encoded = codec.encode(samples);
      expect(encoded.summary, TankPressureSeriesSummary.of(samples));
      expect(encoded.summary.sampleCount, 10);
      expect(encoded.summary.startTimestamp, 0);
      expect(encoded.summary.endTimestamp, 90);
    });
  });

  group('caller errors', () {
    test('an empty series cannot be encoded', () {
      expect(() => codec.encode(const []), throwsArgumentError);
    });

    test('an empty summary is a caller error', () {
      expect(() => TankPressureSeriesSummary.of(const []), throwsArgumentError);
    });

    test('timestamps must be non-decreasing', () {
      const samples = [
        TankPressureSample(timestamp: 10, pressure: 1.0),
        TankPressureSample(timestamp: 9, pressure: 1.0),
      ];
      expect(() => codec.encode(samples), throwsArgumentError);
    });
  });

  group('encode limits', () {
    test('refuses more samples than decode would accept', () {
      expect(
        () => codec.encode(descending(kMaxSeriesSampleCount + 1)),
        throwsArgumentError,
      );
    });
  });

  group('malformed input', () {
    Uint8List validBytes() => codec.encode(descending(8)).bytes;
    Uint8List recompress(List<int> body) =>
        Uint8List.fromList(ZLibCodec(level: 6).encode(body));
    Uint8List inflate(Uint8List bytes) =>
        Uint8List.fromList(zlib.decode(bytes));

    test('bytes that are not a zlib stream', () {
      expect(
        () => codec.decode(Uint8List.fromList([9, 9, 9])),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('an unknown version byte', () {
      final body = inflate(validBytes());
      body[0] = 2;
      expect(
        () => codec.decode(recompress(body)),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('a truncated body', () {
      final body = inflate(validBytes());
      expect(
        () => codec.decode(recompress(body.sublist(0, body.length - 3))),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('trailing bytes', () {
      final body = inflate(validBytes());
      expect(
        () => codec.decode(recompress([...body, 0])),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('a sample count larger than the payload', () {
      final body = inflate(validBytes());
      // Replace the one-byte count (8) with a three-byte varint for 200,000:
      // under the hard cap, so this exercises the payload-size guard.
      expect(body[1], 8, reason: 'the count must still be one byte here');
      const overPayload = [0xC0, 0x9A, 0x0C];
      final tampered = Uint8List.fromList([
        body[0],
        ...overPayload,
        ...body.sublist(2),
      ]);
      expect(
        () => codec.decode(recompress(tampered)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('remaining'),
          ),
        ),
      );
    });

    test('a sample count over the hard cap', () {
      final body = inflate(validBytes());
      // Replace the one-byte count (8) with a five-byte varint for 2^32.
      expect(body[1], 8, reason: 'the count must still be one byte here');
      const huge = [0x80, 0x80, 0x80, 0x80, 0x10];
      final tampered = Uint8List.fromList([
        body[0],
        ...huge,
        ...body.sublist(2),
      ]);
      expect(
        () => codec.decode(recompress(tampered)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('maximum $kMaxSeriesSampleCount'),
          ),
        ),
      );
    });

    test('a body whose timestamp column is absent', () {
      final body = inflate(codec.encode(descending(3)).bytes);
      expect(body[2], kPresenceAll);
      final tampered = Uint8List.fromList([
        body[0],
        body[1],
        kPresenceAbsent,
        ...body.sublist(6),
      ]);
      expect(
        () => codec.decode(recompress(tampered)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('no timestamp'),
          ),
        ),
      );
    });

    test('a body whose pressure column is absent', () {
      final body = inflate(codec.encode(descending(3)).bytes);
      const pressureMode = 6;
      expect(body[pressureMode], kPresenceAll);
      final tampered = Uint8List.fromList([
        ...body.sublist(0, pressureMode),
        kPresenceAbsent,
      ]);
      expect(
        () => codec.decode(recompress(tampered)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('no pressure'),
          ),
        ),
      );
    });

    test('a zero sample count', () {
      final body = Uint8List.fromList([1, 0, 0, 0]);
      expect(
        () => codec.decode(recompress(body)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );
    });
  });
}
