import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/coordinate_parser.dart';

void main() {
  void expectNear(
    ({double latitude, double longitude})? actual,
    double lat,
    double lng, {
    double tolerance = 1e-6,
  }) {
    expect(actual, isNotNull);
    expect(actual!.latitude, closeTo(lat, tolerance));
    expect(actual.longitude, closeTo(lng, tolerance));
  }

  group('decimal degrees', () {
    test('signed pair, the form the app stored before this feature', () {
      expectNear(
        parseCoordinates('20.361944, -87.029722'),
        20.361944,
        -87.029722,
      );
    });

    test('space separated', () {
      expectNear(
        parseCoordinates('20.361944 -87.029722'),
        20.361944,
        -87.029722,
      );
    });

    test('with degree symbols and hemispheres', () {
      expectNear(
        parseCoordinates('20.361944° N, 87.029722° W'),
        20.361944,
        -87.029722,
      );
    });

    test('hemisphere as a prefix', () {
      expectNear(
        parseCoordinates('N20.361944 W87.029722'),
        20.361944,
        -87.029722,
      );
    });
  });

  group('degrees decimal minutes', () {
    test('standard chartplotter form', () {
      expectNear(
        parseCoordinates("20° 21.717' N, 87° 01.783' W"),
        20.36195,
        -87.0297166,
        tolerance: 1e-5,
      );
    });

    test('unicode prime instead of apostrophe', () {
      expectNear(
        parseCoordinates('20° 21.717′ N, 87° 01.783′ W'),
        20.36195,
        -87.0297166,
        tolerance: 1e-5,
      );
    });
  });

  group('degrees minutes seconds', () {
    test('standard form', () {
      expectNear(
        parseCoordinates('20° 21\' 43.0" N, 87° 01\' 47.0" W'),
        20.361944,
        -87.029722,
        tolerance: 1e-4,
      );
    });

    test('unicode double prime', () {
      expectNear(
        parseCoordinates('20° 21′ 43.0″ N, 87° 01′ 47.0″ W'),
        20.361944,
        -87.029722,
        tolerance: 1e-4,
      );
    });

    test('southern and eastern hemispheres', () {
      expectNear(
        parseCoordinates('19° 18\' 19.0" S, 147° 37\' 21.0" E'),
        -19.305278,
        147.6225,
        tolerance: 1e-4,
      );
    });
  });

  group('grid references', () {
    test('mgrs grouped', () {
      expectNear(
        parseCoordinates('16Q DH 96898 51535'),
        20.361944,
        -87.029722,
        tolerance: 2e-5,
      );
    });

    test('mgrs run together', () {
      expectNear(
        parseCoordinates('16QDH9689851535'),
        20.361944,
        -87.029722,
        tolerance: 2e-5,
      );
    });

    test('utm with E/N suffixes', () {
      expectNear(
        parseCoordinates('16Q 496898E 2251535N'),
        20.361944,
        -87.029722,
        tolerance: 2e-5,
      );
    });

    test('utm without suffixes', () {
      expectNear(
        parseCoordinates('16Q 496898 2251535'),
        20.361944,
        -87.029722,
        tolerance: 2e-5,
      );
    });
  });

  group('rejection', () {
    test('rejects junk', () {
      expect(parseCoordinates('somewhere near the reef'), isNull);
      expect(parseCoordinates(''), isNull);
      expect(parseCoordinates('   '), isNull);
    });

    test('rejects out-of-range degrees rather than normalizing, since that '
        'almost always means a typo', () {
      expect(parseCoordinates('91.0, 10.0'), isNull);
      expect(parseCoordinates('10.0, 181.0'), isNull);
    });

    test('rejects impossible minutes and seconds', () {
      expect(parseCoordinates("20° 61.000' N, 87° 01.783' W"), isNull);
      expect(parseCoordinates('20° 21\' 61.0" N, 87° 01\' 47.0" W'), isNull);
    });

    test('rejects a single number, which is not a coordinate pair', () {
      expect(parseCoordinates('20.361944'), isNull);
    });
  });

  group('parseSingleAxis', () {
    test('parses a bare decimal', () {
      expect(
        parseSingleAxis('20.361944', isLatitude: true),
        closeTo(20.361944, 1e-9),
      );
    });

    test('parses a hemisphere-qualified value', () {
      expect(
        parseSingleAxis('87.029722° W', isLatitude: false),
        closeTo(-87.029722, 1e-9),
      );
    });

    test('enforces the axis range', () {
      expect(parseSingleAxis('91.0', isLatitude: true), isNull);
      expect(parseSingleAxis('91.0', isLatitude: false), closeTo(91.0, 1e-9));
    });
  });
}
