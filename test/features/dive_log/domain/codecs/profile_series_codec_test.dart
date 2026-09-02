import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/bounded_inflate.dart';
import 'package:submersion/features/dive_log/domain/codecs/byte_io.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_field_table.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';

/// A fully populated sample: every one of the 28 fields present.
ProfileSample fullSample(int i) => ProfileSample(
  timestamp: i * 10,
  depth: 10.0 + i * 0.5,
  pressure: 200.0 - i,
  temperature: 20.0 - i * 0.01,
  heartRate: 80 + (i % 7),
  ascentRate: -3.0 + i * 0.1,
  ceiling: i > 5 ? 3.0 : 0.0,
  ndl: 1800 - i * 15,
  setpoint: 1.2,
  ppO2: 1.19 + i * 0.001,
  o2Sensor1: 1.18,
  o2Sensor2: 1.20,
  o2Sensor3: 1.21,
  o2Sensor4: 1.17,
  o2Sensor5: 1.22,
  o2Sensor6: 1.19,
  cns: 12.5 + i,
  tts: 900 + i * 3,
  rbt: 1500 - i * 2,
  decoType: i > 5 ? 2 : 0,
  heartRateSource: i < 4 ? 'diveComputer' : 'appleWatch',
  heading: (i * 37) % 360 * 1.0,
  o2SensorMv1: 51 + i,
  o2SensorMv2: 52 - i,
  o2SensorMv3: 53,
  o2SensorMv4: 50,
  o2SensorMv5: 54,
  o2SensorMv6: 52,
);

/// Depth and timestamp only, like a manually entered profile.
ProfileSample minimalSample(int i) =>
    ProfileSample(timestamp: i * 30, depth: 5.0 * (i % 4));

void main() {
  const codec = ProfileSeriesCodec();

  group('round trips', () {
    test('every field present', () {
      final samples = [for (var i = 0; i < 12; i++) fullSample(i)];
      final encoded = codec.encode(samples);
      expect(encoded.codecVersion, 1);
      expect(codec.decode(encoded.bytes), samples);
    });

    test('every optional field null', () {
      final samples = [for (var i = 0; i < 12; i++) minimalSample(i)];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('mixed presence within one column', () {
      final samples = [
        for (var i = 0; i < 20; i++)
          ProfileSample(
            timestamp: i,
            depth: 1.0 * i,
            temperature: i.isEven ? 20.0 : null,
            ndl: i % 3 == 0 ? 600 - i : null,
            heartRateSource: i % 5 == 0 ? 'garmin' : null,
          ),
      ];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('a single sample', () {
      final samples = [fullSample(0)];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('duplicate timestamps survive in insertion order', () {
      const samples = [
        ProfileSample(timestamp: 10, depth: 5.0),
        ProfileSample(timestamp: 10, depth: 5.5),
        ProfileSample(timestamp: 10, depth: 5.0, temperature: 19.0),
        ProfileSample(timestamp: 20, depth: 6.0),
      ];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('integer fields that decrease encode negative deltas correctly', () {
      final samples = [
        for (var i = 0; i < 50; i++)
          ProfileSample(
            timestamp: i,
            depth: 1.0,
            ndl: 3000 - i * 60,
            rbt: 2000 - i * 45,
            heartRate: 100 - i,
            o2SensorMv1: -5 + i,
          ),
      ];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('float64 fields are bit-exact', () {
      const samples = [
        ProfileSample(timestamp: 0, depth: 0.1 + 0.2, temperature: -0.0),
        ProfileSample(timestamp: 1, depth: double.maxFinite, cns: 1e-300),
      ];
      final decoded = codec.decode(codec.encode(samples).bytes);
      expect(decoded[0].depth, samples[0].depth);
      expect(decoded[0].temperature!.isNegative, isTrue);
      expect(decoded[1].depth, double.maxFinite);
      expect(decoded[1].cns, 1e-300);
    });

    test('the largest realistic series: 20,000 samples at one second', () {
      final random = Random(42);
      var depth = 0.0;
      final samples = <ProfileSample>[];
      for (var i = 0; i < 20000; i++) {
        depth = max(0.0, depth + (random.nextDouble() - 0.5) * 0.3);
        samples.add(
          ProfileSample(
            timestamp: i,
            depth: depth,
            temperature: 8.0 + (i ~/ 600) * 0.1,
            ndl: max(0, 3600 - i ~/ 2),
            cns: i / 400.0,
            decoType: i > 15000 ? 2 : 0,
          ),
        );
      }
      final encoded = codec.encode(samples);
      expect(codec.decode(encoded.bytes), samples);
      // 20,000 samples of six fields. Row storage today costs roughly 300
      // bytes per sample; the packed blob must land far below even the raw
      // columnar size (8 bytes per float64 field per sample).
      expect(encoded.bytes.length, lessThan(20000 * 3 * 8));
    });
  });

  group('summary', () {
    test('encode returns the summary of the packed samples', () {
      final samples = [for (var i = 0; i < 12; i++) fullSample(i)];
      final encoded = codec.encode(samples);
      expect(encoded.summary, ProfileSeriesSummary.of(samples));
      expect(encoded.summary.sampleCount, 12);
      expect(encoded.summary.hasDecoStop, isTrue);
      expect(encoded.summary.hasPositiveCeiling, isTrue);
    });
  });

  group('caller errors', () {
    test('an empty series cannot be encoded', () {
      expect(() => codec.encode(const []), throwsArgumentError);
    });

    test('timestamps must be non-decreasing', () {
      const samples = [
        ProfileSample(timestamp: 10, depth: 1.0),
        ProfileSample(timestamp: 9, depth: 1.0),
      ];
      expect(() => codec.encode(samples), throwsArgumentError);
    });

    test('an unregistered version cannot be encoded', () {
      expect(
        () => codec.encode([fullSample(0)], version: 9),
        throwsArgumentError,
      );
    });

    test('a field table naming an unknown field cannot be encoded', () {
      // timestamp and depth satisfy _validateTable; the encoder only fails
      // once it reaches the bogus column while building it.
      const table = [
        ProfileField('timestamp', ProfileFieldKind.deltaInt),
        ProfileField('depth', ProfileFieldKind.float64),
        ProfileField('not_a_real_field', ProfileFieldKind.float64),
      ];
      const withUnknownField = ProfileSeriesCodec(fieldTables: {9: table});
      expect(
        () => withUnknownField.encode([fullSample(0)], version: 9),
        throwsArgumentError,
      );
    });
  });

  group('encode limits', () {
    test('refuses more samples than decode would accept', () {
      // encode and decode have to agree: part 2 drops the source rows once
      // a series is packed, so a blob decode refuses is unrecoverable.
      final tooMany = [
        for (var i = 0; i < kMaxSeriesSampleCount + 1; i++) minimalSample(i),
      ];
      expect(() => codec.encode(tooMany), throwsArgumentError);
    });

    test('a field table may not change a v1 field kind', () {
      // cast() is lazy, so without this the mismatch escapes as a TypeError
      // from inside a presence loop rather than as a table error.
      const table = [
        ProfileField('timestamp', ProfileFieldKind.deltaInt),
        ProfileField('depth', ProfileFieldKind.float64),
        ProfileField('cns', ProfileFieldKind.deltaInt),
      ];
      const wrong = ProfileSeriesCodec(fieldTables: {9: table});
      expect(
        () => wrong.encode([fullSample(0)], version: 9),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('cns is float64 in v1'),
          ),
        ),
      );
    });
  });

  group('malformed input', () {
    test('a blob whose timestamps decrease is refused', () {
      // encode enforces this and every consumer assumes it: the merge
      // interleaves on timestamp, the aggregates difference consecutive
      // samples, and the summary takes first and last rather than min and
      // max. A crafted or bit-rotted delta could otherwise hand all of them
      // an out-of-order series with no complaint.
      final body = ByteWriter()
        ..writeByte(1)
        ..writeVarUint(2);
      // timestamp column: present, deltas +100 then -40.
      body.writeColumn<int>([100, -40], body.writeVarInt);
      // depth column, then every remaining field absent.
      body.writeColumn<double>([1.0, 2.0], body.writeFloat64);
      for (var i = 2; i < kProfileFieldTableV1.length; i++) {
        body.writeByte(kPresenceAbsent);
      }
      final blob = Uint8List.fromList(
        ZLibCodec(level: 6).encode(body.takeBytes()),
      );

      expect(
        () => const ProfileSeriesCodec().decode(blob),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('decreases'),
          ),
        ),
      );
    });

    Uint8List validBytes() =>
        codec.encode([for (var i = 0; i < 8; i++) fullSample(i)]).bytes;

    /// Re-compresses a tampered body so the failure is in the codec, not
    /// in zlib.
    Uint8List recompress(List<int> body) =>
        Uint8List.fromList(ZLibCodec(level: 6).encode(body));

    Uint8List inflate(Uint8List bytes) =>
        Uint8List.fromList(zlib.decode(bytes));

    test('bytes that are not a zlib stream', () {
      expect(
        () => codec.decode(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('an empty blob', () {
      expect(
        () => codec.decode(Uint8List(0)),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('an unknown version byte', () {
      final body = inflate(validBytes());
      body[0] = 42;
      expect(
        () => codec.decode(recompress(body)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('version'),
          ),
        ),
      );
    });

    test('a truncated body', () {
      final body = inflate(validBytes());
      final truncated = body.sublist(0, body.length ~/ 2);
      expect(
        () => codec.decode(recompress(truncated)),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('trailing bytes after the last block', () {
      final body = inflate(validBytes());
      final padded = Uint8List.fromList([...body, 0, 0, 0]);
      expect(
        () => codec.decode(recompress(padded)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('trailing'),
          ),
        ),
      );
    });

    test('a body whose timestamp column is absent', () {
      // [version 9][count 3][timestamp: mode, 3 deltas][depth: mode, 3 floats]
      const table = [
        ProfileField('timestamp', ProfileFieldKind.deltaInt),
        ProfileField('depth', ProfileFieldKind.float64),
      ];
      const small = ProfileSeriesCodec(fieldTables: {9: table});
      const samples = [
        ProfileSample(timestamp: 0, depth: 1.5),
        ProfileSample(timestamp: 10, depth: 2.5),
        ProfileSample(timestamp: 20, depth: 3.5),
      ];
      final body = inflate(small.encode(samples, version: 9).bytes);
      expect(body[2], kPresenceAll);
      // Mark the timestamp column absent and drop its three delta bytes.
      final tampered = Uint8List.fromList([
        body[0],
        body[1],
        kPresenceAbsent,
        ...body.sublist(6),
      ]);
      expect(
        () => small.decode(recompress(tampered)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('no timestamp'),
          ),
        ),
      );
    });

    test('a body whose depth column is absent', () {
      const table = [
        ProfileField('timestamp', ProfileFieldKind.deltaInt),
        ProfileField('depth', ProfileFieldKind.float64),
      ];
      const small = ProfileSeriesCodec(fieldTables: {9: table});
      const samples = [
        ProfileSample(timestamp: 0, depth: 1.5),
        ProfileSample(timestamp: 10, depth: 2.5),
        ProfileSample(timestamp: 20, depth: 3.5),
      ];
      final body = inflate(small.encode(samples, version: 9).bytes);
      // Depth block starts after version, count, timestamp mode, 3 deltas.
      const depthMode = 6;
      expect(body[depthMode], kPresenceAll);
      final tampered = Uint8List.fromList([
        ...body.sublist(0, depthMode),
        kPresenceAbsent,
      ]);
      expect(
        () => small.decode(recompress(tampered)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('no depth'),
          ),
        ),
      );
    });

    test('malformed UTF-8 in a string run', () {
      const table = [
        ProfileField('timestamp', ProfileFieldKind.deltaInt),
        ProfileField('depth', ProfileFieldKind.float64),
        ProfileField('heart_rate_source', ProfileFieldKind.runLengthString),
      ];
      const small = ProfileSeriesCodec(fieldTables: {9: table});
      const samples = [
        ProfileSample(timestamp: 0, depth: 1.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 1, depth: 2.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 2, depth: 3.0, heartRateSource: 'a'),
      ];
      final body = inflate(small.encode(samples, version: 9).bytes);
      const firstStringByte = 1 + 1 + (1 + 3) + (1 + 24) + 1 + 1 + 1 + 1;
      expect(body[firstStringByte], 0x61);
      body[firstStringByte] = 0xFF;
      expect(
        () => small.decode(recompress(body)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('UTF-8'),
          ),
        ),
      );
    });

    test('a zero sample count', () {
      // [version 1][count 0] then 28 absent blocks.
      final body = Uint8List.fromList([1, 0, ...List.filled(28, 0)]);
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
      // The cap is checked before the payload guard, so no crafted body has
      // to be large enough to make the count plausible.
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

    test('a sample count of exactly the cap clears the cap guard', () {
      // Pins which side of the boundary the cap sits on: this count is
      // legal, so it must fall through to the payload guard instead. An
      // off-by-one to >= would make every maximal series undecodable.
      final body = inflate(validBytes());
      expect(body[1], 8, reason: 'the count must still be one byte here');
      final atCap = ByteWriter()..writeVarUint(kMaxSeriesSampleCount);
      final tampered = Uint8List.fromList([
        body[0],
        ...atCap.takeBytes(),
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

    test('a sample count one past the cap is refused by the cap', () {
      final body = inflate(validBytes());
      expect(body[1], 8, reason: 'the count must still be one byte here');
      final pastCap = ByteWriter()..writeVarUint(kMaxSeriesSampleCount + 1);
      final tampered = Uint8List.fromList([
        body[0],
        ...pastCap.takeBytes(),
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

    test('a string run length near 2^63 does not overrun the guard', () {
      // values.length + length would wrap negative and let the append loop
      // run unbounded, which no sample-count cap can see: the declared
      // count here is a legitimate 3.
      const table = [
        ProfileField('timestamp', ProfileFieldKind.deltaInt),
        ProfileField('depth', ProfileFieldKind.float64),
        ProfileField('heart_rate_source', ProfileFieldKind.runLengthString),
      ];
      const small = ProfileSeriesCodec(fieldTables: {9: table});
      const samples = [
        ProfileSample(timestamp: 0, depth: 1.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 1, depth: 2.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 2, depth: 3.0, heartRateSource: 'a'),
      ];
      final body = inflate(small.encode(samples, version: 9).bytes);
      const runLengthOffset = 1 + 1 + (1 + 3) + (1 + 24) + 1 + 1;
      expect(body[runLengthOffset], 3);
      final huge = ByteWriter()..writeVarUint(maxVarInt * 2 + 1);
      final tampered = Uint8List.fromList([
        ...body.sublist(0, runLengthOffset),
        ...huge.takeBytes(),
        ...body.sublist(runLengthOffset + 1),
      ]);
      expect(
        () => small.decode(recompress(tampered)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('overruns'),
          ),
        ),
      );
    });

    test('a zero-length string run is refused', () {
      // Accepting one would make the format non-canonical: padding runs
      // decode to the same samples from different bytes.
      const table = [
        ProfileField('timestamp', ProfileFieldKind.deltaInt),
        ProfileField('depth', ProfileFieldKind.float64),
        ProfileField('heart_rate_source', ProfileFieldKind.runLengthString),
      ];
      const small = ProfileSeriesCodec(fieldTables: {9: table});
      const samples = [
        ProfileSample(timestamp: 0, depth: 1.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 1, depth: 2.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 2, depth: 3.0, heartRateSource: 'a'),
      ];
      final body = inflate(small.encode(samples, version: 9).bytes);
      const runLengthOffset = 1 + 1 + (1 + 3) + (1 + 24) + 1 + 1;
      expect(body[runLengthOffset], 3);
      body[runLengthOffset] = 0;
      expect(
        () => small.decode(recompress(body)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );
    });

    test('a string run longer than the present values', () {
      // A three-field table keeps the body small enough to address by hand:
      // [version][count 3][timestamp: mode, 3 deltas][depth: mode, 3 floats]
      // [heart_rate_source: mode, run count, run length, byte length, 'a'].
      const table = [
        ProfileField('timestamp', ProfileFieldKind.deltaInt),
        ProfileField('depth', ProfileFieldKind.float64),
        ProfileField('heart_rate_source', ProfileFieldKind.runLengthString),
      ];
      const small = ProfileSeriesCodec(fieldTables: {9: table});
      const samples = [
        ProfileSample(timestamp: 0, depth: 1.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 1, depth: 2.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 2, depth: 3.0, heartRateSource: 'a'),
      ];
      final body = inflate(small.encode(samples, version: 9).bytes);
      const runLengthOffset = 1 + 1 + (1 + 3) + (1 + 24) + 1 + 1;
      expect(body[runLengthOffset], 3);
      body[runLengthOffset] = 5;
      expect(
        () => small.decode(recompress(body)),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('string runs that undercount the present values', () {
      // Same table and byte layout as the run-length-overrun test above,
      // but the run length is shrunk rather than grown: the per-run bound
      // (values.length + length > presentCount) never trips, so decoding
      // reaches the total-coverage check after the loop instead.
      const table = [
        ProfileField('timestamp', ProfileFieldKind.deltaInt),
        ProfileField('depth', ProfileFieldKind.float64),
        ProfileField('heart_rate_source', ProfileFieldKind.runLengthString),
      ];
      const small = ProfileSeriesCodec(fieldTables: {9: table});
      const samples = [
        ProfileSample(timestamp: 0, depth: 1.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 1, depth: 2.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 2, depth: 3.0, heartRateSource: 'a'),
      ];
      final body = inflate(small.encode(samples, version: 9).bytes);
      const runLengthOffset = 1 + 1 + (1 + 3) + (1 + 24) + 1 + 1;
      expect(body[runLengthOffset], 3);
      body[runLengthOffset] = 2;
      expect(
        () => small.decode(recompress(body)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            'string runs cover 2 of 3 present values',
          ),
        ),
      );
    });
  });

  group('hostile input', () {
    /// The three-field table the by-hand bodies below are written against:
    /// [version][count][timestamp block][depth block][string block].
    const table = [
      ProfileField('timestamp', ProfileFieldKind.deltaInt),
      ProfileField('depth', ProfileFieldKind.float64),
      ProfileField('heart_rate_source', ProfileFieldKind.runLengthString),
    ];
    const small = ProfileSeriesCodec(fieldTables: {9: table});

    /// A body for three fully present samples whose string column carries
    /// [runs] verbatim as (run length, byte length, bytes) triples.
    Uint8List blobWithStringRuns(List<(int, int, List<int>)> runs) {
      final writer = ByteWriter()
        ..writeByte(9)
        ..writeVarUint(3)
        ..writeByte(kPresenceAll)
        ..writeVarInt(0)
        ..writeVarInt(1)
        ..writeVarInt(1)
        ..writeByte(kPresenceAll)
        ..writeFloat64(1)
        ..writeFloat64(2)
        ..writeFloat64(3)
        ..writeByte(kPresenceAll)
        ..writeVarUint(runs.length);
      for (final (length, byteLength, bytes) in runs) {
        writer
          ..writeVarUint(length)
          ..writeVarUint(byteLength)
          ..writeBytes(bytes);
      }
      return Uint8List.fromList(ZLibCodec(level: 6).encode(writer.takeBytes()));
    }

    test('a string run length near 2^63 is refused, not looped over', () {
      // One legitimate run puts a value in the accumulator, so the second
      // run's length plus that value wraps negative under an additive
      // guard and the run loop never terminates.
      final blob = blobWithStringRuns([
        (1, 1, utf8.encode('a')),
        ((1 << 63) - 1, 1, utf8.encode('b')),
      ]);
      expect(
        () => small.decode(blob),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('a string run byte length near 2^63 is refused', () {
      final blob = blobWithStringRuns([(3, (1 << 63) - 1, utf8.encode('abc'))]);
      expect(
        () => small.decode(blob),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('an inflated body over the cap is refused', () {
      final oversized = Uint8List.fromList(
        ZLibCodec(level: 6).encode(Uint8List(kMaxSeriesBodyBytes + 1)),
      );
      // A few kilobytes of stored blob, tens of megabytes once inflated.
      expect(oversized.length, lessThan(1 << 20));
      expect(
        () => codec.decode(oversized),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('inflate'),
          ),
        ),
      );
    });

    test('a body just under the cap is still inflated', () {
      // The cap refuses only what exceeds it. This body inflates fine and
      // then fails on its content, which proves the inflate itself ran.
      final justUnder = Uint8List.fromList(
        ZLibCodec(level: 6).encode(Uint8List(kMaxSeriesBodyBytes)),
      );
      expect(
        () => codec.decode(justUnder),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            isNot(contains('inflate')),
          ),
        ),
      );
    });

    test('a twenty thousand sample series with every field round trips', () {
      final samples = [for (var i = 0; i < 20000; i++) fullSample(i)];
      final encoded = codec.encode(samples);
      expect(codec.decode(encoded.bytes), samples);
    });
  });

  group('forward tolerance', () {
    // A hypothetical older format that never recorded heading.
    final withoutHeading = [
      for (final field in ProfileSeriesCodec.fieldTableV1)
        if (field.name != 'heading') field,
    ];

    test('a newer decoder reads an older version with missing fields null', () {
      final legacy = ProfileSeriesCodec(fieldTables: {7: withoutHeading});
      final modern = ProfileSeriesCodec(
        fieldTables: {
          7: withoutHeading,
          ProfileSeriesCodec.version: ProfileSeriesCodec.fieldTableV1,
        },
      );
      final samples = [for (var i = 0; i < 6; i++) fullSample(i)];
      final bytes = legacy.encode(samples, version: 7).bytes;
      final decoded = modern.decode(bytes);
      expect(decoded, hasLength(6));
      for (var i = 0; i < 6; i++) {
        expect(decoded[i].heading, isNull);
        expect(decoded[i], samples[i].copyWithoutHeading());
      }
    });

    test('a decoder that does not know the version refuses it', () {
      final legacy = ProfileSeriesCodec(fieldTables: {7: withoutHeading});
      final bytes = legacy.encode([fullSample(0)], version: 7).bytes;
      expect(
        () => codec.decode(bytes),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('every field table must carry timestamp and depth', () {
      final noDepth = [
        for (final field in ProfileSeriesCodec.fieldTableV1)
          if (field.name != 'depth') field,
      ];
      expect(
        () => ProfileSeriesCodec(
          fieldTables: {1: noDepth},
        ).encode([fullSample(0)]),
        throwsArgumentError,
      );
    });

    test('a field table with a duplicate name is refused on both sides', () {
      final duplicated = [
        ...ProfileSeriesCodec.fieldTableV1,
        const ProfileField('depth', ProfileFieldKind.float64),
      ];
      final bad = ProfileSeriesCodec(fieldTables: {1: duplicated});
      expect(() => bad.encode([fullSample(0)]), throwsArgumentError);
      final bytes = codec.encode([fullSample(0)]).bytes;
      expect(() => bad.decode(bytes), throwsArgumentError);
    });
  });

  group('field table', () {
    test('v1 has 28 entries with unique names', () {
      final names = ProfileSeriesCodec.fieldTableV1.map((f) => f.name);
      expect(names, hasLength(28));
      expect(names.toSet(), hasLength(28));
    });

    test('v1 begins with timestamp and depth', () {
      expect(ProfileSeriesCodec.fieldTableV1[0].name, 'timestamp');
      expect(ProfileSeriesCodec.fieldTableV1[1].name, 'depth');
    });
  });
}

extension on ProfileSample {
  ProfileSample copyWithoutHeading() => ProfileSample(
    timestamp: timestamp,
    depth: depth,
    pressure: pressure,
    temperature: temperature,
    heartRate: heartRate,
    ascentRate: ascentRate,
    ceiling: ceiling,
    ndl: ndl,
    setpoint: setpoint,
    ppO2: ppO2,
    o2Sensor1: o2Sensor1,
    o2Sensor2: o2Sensor2,
    o2Sensor3: o2Sensor3,
    o2Sensor4: o2Sensor4,
    o2Sensor5: o2Sensor5,
    o2Sensor6: o2Sensor6,
    cns: cns,
    tts: tts,
    rbt: rbt,
    decoType: decoType,
    heartRateSource: heartRateSource,
    o2SensorMv1: o2SensorMv1,
    o2SensorMv2: o2SensorMv2,
    o2SensorMv3: o2SensorMv3,
    o2SensorMv4: o2SensorMv4,
    o2SensorMv5: o2SensorMv5,
    o2SensorMv6: o2SensorMv6,
  );
}
