import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_point_codec.dart';

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
