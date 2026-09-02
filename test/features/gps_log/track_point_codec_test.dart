import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_point_codec.dart';

/// Wraps [json] the way [encodeTrackPoints] would, without going through it,
/// so a payload the encoder would refuse to write can still be decoded.
Uint8List _blobOf(String json) =>
    Uint8List.fromList(gzip.encode(utf8.encode(json)));

void main() {
  group('encode/decode round-trip', () {
    test('preserves points exactly', () {
      final points = [
        const GpsTrackPoint(
          timestamp: 1700000000,
          latitude: 20.123456,
          longitude: -87.654321,
          accuracy: 8.5,
        ),
        const GpsTrackPoint(
          timestamp: 1700000060,
          latitude: 20.123999,
          longitude: -87.654001,
          accuracy: null,
        ),
      ];
      final decoded = decodeTrackPoints(encodeTrackPoints(points));
      expect(decoded.length, 2);
      expect(decoded[0].timestamp, 1700000000);
      expect(decoded[0].latitude, closeTo(20.123456, 1e-9));
      expect(decoded[0].longitude, closeTo(-87.654321, 1e-9));
      expect(decoded[0].accuracy, closeTo(8.5, 1e-9));
      expect(decoded[1].accuracy, isNull);
    });

    test('empty list round-trips', () {
      expect(decodeTrackPoints(encodeTrackPoints(const [])), isEmpty);
    });

    test('compresses a large track well below raw JSON size', () {
      final points = List.generate(
        3600,
        (i) => GpsTrackPoint(
          timestamp: 1700000000 + i * 10,
          latitude: 20.0 + i * 0.00001,
          longitude: -87.0 - i * 0.00001,
          accuracy: 10,
        ),
      );
      final blob = encodeTrackPoints(points);
      // 3600 points raw JSON is ~200 KB; gzip should be far smaller.
      expect(blob.length, lessThan(100 * 1024));
      expect(decodeTrackPoints(blob).length, 3600);
    });
  });

  group('decode rejects a hostile blob', () {
    test('abandons a compression bomb instead of inflating it', () {
      // Zeros gzip to almost nothing, which is the whole shape of the
      // attack: a blob small enough to sync inflates to a body no phone can
      // hold. Sized past the body cap, not past memory, so the test itself
      // stays cheap.
      final bomb = Uint8List.fromList(
        gzip.encode(Uint8List(kMaxTrackBodyBytes + 1)),
      );
      expect(bomb.length, lessThan(kMaxTrackBlobBytes));
      expect(
        () => decodeTrackPoints(bomb),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('refuses a blob longer than the blob cap', () {
      final oversized = Uint8List(kMaxTrackBlobBytes + 1);
      expect(
        () => decodeTrackPoints(oversized),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('refuses more points than the codec will write', () {
      final tuples = List.filled(
        kMaxTrackPointCount + 1,
        '[0,0,0,null]',
      ).join(',');
      expect(
        () => decodeTrackPoints(_blobOf('[$tuples]')),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('refuses a comma-dense body before it is parsed', () {
      // The densest legal tuple, repeated to fill the body cap. Measured at
      // 3.35 million of them, jsonDecode alone cost about 370 MB before any
      // count could be checked, which is the whole reason the comma bound
      // runs first.
      final tuples = List.filled(kMaxTrackBodyCommas, '[0,0,0,0]').join(',');
      expect(
        () => decodeTrackPoints(_blobOf('[$tuples]')),
        throwsA(
          isA<TrackPointCodecException>().having(
            (e) => e.message,
            'message',
            contains('comma'),
          ),
        ),
      );
    });

    test('a flat array of scalars is refused on commas too', () {
      // No inner brackets at all, so an element count that leans on tuple
      // structure would miss this entirely.
      final scalars = List.filled(kMaxTrackBodyCommas + 2, '0').join(',');
      expect(
        () => decodeTrackPoints(_blobOf('[$scalars]')),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('a maximal legitimate track sits inside the comma bound', () {
      // The encoder writes 4N-1 commas for N points, so the cap must not
      // refuse what encodeTrackPoints is willing to write.
      final points = List.generate(
        kMaxTrackPointCount,
        (i) => const GpsTrackPoint(timestamp: 0, latitude: 0, longitude: 0),
      );
      final blob = encodeTrackPoints(points);
      expect(decodeTrackPoints(blob).length, kMaxTrackPointCount);
    });

    test('accepts exactly the point cap', () {
      final tuples = List.filled(kMaxTrackPointCount, '[0,0,0,null]').join(',');
      expect(
        decodeTrackPoints(_blobOf('[$tuples]')).length,
        kMaxTrackPointCount,
      );
    });
  });

  group('decode rejects a malformed blob with one declared type', () {
    test('bytes that are not a compressed stream', () {
      expect(
        () => decodeTrackPoints(Uint8List.fromList(List.filled(64, 0xAB))),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('a body that is not valid UTF-8, named as such', () {
      // Bytes and JSON are distinct failures. Reporting a body that failed
      // as bytes as though it were bad JSON sends a reader looking for the
      // wrong thing.
      final blob = Uint8List.fromList(gzip.encode(const [0xC3, 0x28]));
      expect(
        () => decodeTrackPoints(blob),
        throwsA(
          isA<TrackPointCodecException>().having(
            (e) => e.message,
            'message',
            contains('UTF-8'),
          ),
        ),
      );
    });

    test('a body that is not valid JSON, named as such', () {
      expect(
        () => decodeTrackPoints(_blobOf('[[1,2,3,')),
        throwsA(
          isA<TrackPointCodecException>().having(
            (e) => e.message,
            'message',
            contains('JSON'),
          ),
        ),
      );
    });

    test('a JSON object where an array belongs', () {
      expect(
        () => decodeTrackPoints(_blobOf('{"a":1}')),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('a tuple that is too short', () {
      expect(
        () => decodeTrackPoints(_blobOf('[[1,2]]')),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('a tuple that is too long', () {
      expect(
        () => decodeTrackPoints(_blobOf('[[1,2,3,4,5]]')),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('an element that is not a tuple at all', () {
      expect(
        () => decodeTrackPoints(_blobOf('["x",2,3,4]')),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('a non-numeric timestamp, reported by type not by value', () {
      expect(
        () => decodeTrackPoints(_blobOf('[["x",1,2,null]]')),
        throwsA(
          isA<TrackPointCodecException>().having(
            (e) => e.message,
            'message',
            allOf(contains('non-numeric timestamp'), contains('String')),
          ),
        ),
      );
    });

    test('never puts a rejected value into the message', () {
      // Nothing upstream bounds a single element: this body carries three
      // commas, so it clears the comma cap, and its one string clears the
      // body cap. Interpolating it was measured building a 20,971,556
      // character message, which the repository logs whole.
      final huge = 'A' * (1024 * 1024);
      final blob = _blobOf('[["$huge",0,0,0]]');
      expect(
        () => decodeTrackPoints(blob),
        throwsA(
          isA<TrackPointCodecException>()
              .having((e) => e.message.length, 'message length', lessThan(120))
              .having((e) => e.message, 'message', isNot(contains('AAAA'))),
        ),
      );
    });

    test('a null coordinate', () {
      expect(
        () => decodeTrackPoints(_blobOf('[[1,null,2,null]]')),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('a non-numeric accuracy', () {
      expect(
        () => decodeTrackPoints(_blobOf('[[1,2,3,"x"]]')),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('a non-finite number, which is safe to name', () {
      // JSON has no infinity literal, but an out-of-range exponent such as
      // 1e999 parses to Infinity, and toInt() on an infinity throws an
      // UnsupportedError no caller expects. A non-finite num is NaN or an
      // infinity, so printing it cannot grow.
      expect(
        () => decodeTrackPoints(_blobOf('[[1e999,1,2,null]]')),
        throwsA(
          isA<TrackPointCodecException>().having(
            (e) => e.message,
            'message',
            allOf(contains('non-finite timestamp'), contains('Infinity')),
          ),
        ),
      );
    });
  });

  group('encode refuses what decode would reject', () {
    test('a track over the point cap', () {
      final points = List.generate(
        kMaxTrackPointCount + 1,
        (i) => const GpsTrackPoint(timestamp: 0, latitude: 0, longitude: 0),
      );
      expect(
        () => encodeTrackPoints(points),
        throwsA(isA<TrackPointCodecException>()),
      );
    });

    test('a track at exactly the point cap still writes', () {
      final points = List.generate(
        kMaxTrackPointCount,
        (i) => const GpsTrackPoint(timestamp: 0, latitude: 0, longitude: 0),
      );
      expect(encodeTrackPoints(points), isNotEmpty);
    });
  });

  group('toWallClockEpochSeconds', () {
    test('reinterprets local wall clock as UTC', () {
      // A real-UTC instant. Its local wall-clock components, read in the
      // test runner's timezone, reinterpreted as UTC, must equal the result.
      final utc = DateTime.utc(2026, 7, 6, 15, 30, 45);
      final local = utc.toLocal();
      final expected =
          DateTime.utc(
            local.year,
            local.month,
            local.day,
            local.hour,
            local.minute,
            local.second,
          ).millisecondsSinceEpoch ~/
          1000;
      expect(toWallClockEpochSeconds(utc), expected);
    });

    test('differs from real UTC by the local offset', () {
      final utc = DateTime.utc(2026, 7, 6, 15, 30, 45);
      final offsetSeconds = utc.toLocal().timeZoneOffset.inSeconds;
      expect(
        toWallClockEpochSeconds(utc) - utc.millisecondsSinceEpoch ~/ 1000,
        offsetSeconds,
      );
    });
  });
}
