import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_point_codec.dart';

NavTrackPoint _p({
  int timestamp = 0,
  double north = 0,
  double east = 0,
  double depth = 0,
  double? course,
  double? pitch,
  double? roll,
  double? distance,
  double? speed,
  double? temperature,
  double? batteryVolts,
}) => NavTrackPoint(
  timestamp: timestamp,
  north: north,
  east: east,
  depth: depth,
  course: course,
  pitch: pitch,
  roll: roll,
  distance: distance,
  speed: speed,
  temperature: temperature,
  batteryVolts: batteryVolts,
);

void main() {
  group('encodeNavTrackPoints / decodeNavTrackPoints round trip', () {
    test('round-trips a single fully-populated point', () {
      final points = [
        _p(
          timestamp: 1000,
          north: 12.5,
          east: -3.25,
          depth: 8.7,
          course: 240.4,
          pitch: 2.6,
          roll: 8.5,
          distance: 100.5,
          speed: 0.42,
          temperature: 23.7,
          batteryVolts: 3.88,
        ),
      ];
      final blob = encodeNavTrackPoints(points);
      final decoded = decodeNavTrackPoints(blob);
      expect(decoded.length, 1);
      final p = decoded.single;
      expect(p.timestamp, 1000);
      expect(p.north, 12.5);
      expect(p.east, -3.25);
      expect(p.depth, 8.7);
      expect(p.course, 240.4);
      expect(p.pitch, 2.6);
      expect(p.roll, 8.5);
      expect(p.distance, 100.5);
      expect(p.speed, 0.42);
      expect(p.temperature, 23.7);
      expect(p.batteryVolts, 3.88);
    });

    test('round-trips every optional channel as null', () {
      final points = [_p(timestamp: 5, north: 1, east: 2, depth: 3)];
      final decoded = decodeNavTrackPoints(encodeNavTrackPoints(points));
      final p = decoded.single;
      expect(p.course, isNull);
      expect(p.pitch, isNull);
      expect(p.roll, isNull);
      expect(p.distance, isNull);
      expect(p.speed, isNull);
      expect(p.temperature, isNull);
      expect(p.batteryVolts, isNull);
    });

    test('round-trips many points in order', () {
      final points = [
        for (var i = 0; i < 500; i++)
          _p(
            timestamp: 1000 + i,
            north: i * 0.5,
            east: -i * 0.25,
            depth: (i % 40).toDouble(),
            speed: i.isEven ? i / 100 : null,
          ),
      ];
      final decoded = decodeNavTrackPoints(encodeNavTrackPoints(points));
      expect(decoded.length, points.length);
      for (var i = 0; i < points.length; i++) {
        expect(decoded[i].timestamp, points[i].timestamp);
        expect(decoded[i].north, points[i].north);
        expect(decoded[i].east, points[i].east);
        expect(decoded[i].depth, points[i].depth);
        expect(decoded[i].speed, points[i].speed);
      }
    });

    test('round-trips a negative depth-adjacent value exactly (no clamping '
        'happens in the codec)', () {
      // The parser clamps small negative depths to zero; the codec must
      // not repeat or second-guess that -- it stores whatever it is given.
      final points = [_p(timestamp: 0, north: 0, east: 0, depth: -0.2)];
      final decoded = decodeNavTrackPoints(encodeNavTrackPoints(points));
      expect(decoded.single.depth, -0.2);
    });

    test('round-trips an empty route', () {
      final decoded = decodeNavTrackPoints(encodeNavTrackPoints(const []));
      expect(decoded, isEmpty);
    });
  });

  group('encodeNavTrackPoints', () {
    test('refuses more than kMaxNavTrackPointCount points', () {
      final points = List.generate(
        kMaxNavTrackPointCount + 1,
        (i) => _p(timestamp: i, north: 0, east: 0, depth: 0),
      );
      expect(
        () => encodeNavTrackPoints(points),
        throwsA(isA<NavTrackCodecException>()),
      );
    });
  });

  group('decodeNavTrackPoints error handling', () {
    Uint8List gzipOf(String jsonText) =>
        Uint8List.fromList(gzip.encode(utf8.encode(jsonText)));

    test('rejects a non-gzip blob', () {
      expect(
        () => decodeNavTrackPoints(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<NavTrackCodecException>()),
      );
    });

    test('rejects a blob whose body is not a JSON array', () {
      expect(
        () => decodeNavTrackPoints(gzipOf('{"not":"an array"}')),
        throwsA(isA<NavTrackCodecException>()),
      );
    });

    test('rejects a blob whose body is not valid JSON', () {
      expect(
        () => decodeNavTrackPoints(gzipOf('not json at all')),
        throwsA(isA<NavTrackCodecException>()),
      );
    });

    test('rejects a tuple with the wrong element count', () {
      expect(
        () => decodeNavTrackPoints(gzipOf('[[0,0,0]]')),
        throwsA(isA<NavTrackCodecException>()),
      );
    });

    test('rejects a tuple with a non-numeric required field', () {
      expect(
        () => decodeNavTrackPoints(
          gzipOf('[[0,"north",0,0,null,null,null,null,null,null,null]]'),
        ),
        throwsA(isA<NavTrackCodecException>()),
      );
    });

    test('rejects a tuple with a non-finite value', () {
      // JSON has no infinity literal, but an out-of-range exponent parses
      // to one, which must not survive into a NavTrackPoint field.
      expect(
        () => decodeNavTrackPoints(
          gzipOf('[[0,1e999,0,0,null,null,null,null,null,null,null]]'),
        ),
        throwsA(isA<NavTrackCodecException>()),
      );
    });

    test('accepts null for every optional field', () {
      final decoded = decodeNavTrackPoints(
        gzipOf('[[0,1,2,3,null,null,null,null,null,null,null]]'),
      );
      final p = decoded.single;
      expect(p.timestamp, 0);
      expect(p.north, 1);
      expect(p.east, 2);
      expect(p.depth, 3);
      expect(p.course, isNull);
      expect(p.batteryVolts, isNull);
    });

    test(
      'rejects a blob declaring more than kMaxNavTrackPointCount points',
      () {
        final tuples = List.generate(
          kMaxNavTrackPointCount + 1,
          (_) => '[0,0,0,0,null,null,null,null,null,null,null]',
        ).join(',');
        expect(
          () => decodeNavTrackPoints(gzipOf('[$tuples]')),
          throwsA(isA<NavTrackCodecException>()),
        );
      },
    );
  });
}
