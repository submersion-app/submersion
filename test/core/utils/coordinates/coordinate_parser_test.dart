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

    // Issue #2035: divers in comma-decimal locales type the decimal
    // separator they use everywhere else.
    test('reads a comma as the decimal separator', () {
      expect(
        parseSingleAxis('48,8566', isLatitude: true),
        closeTo(48.8566, 1e-9),
      );
      expect(
        parseSingleAxis('-4,5678', isLatitude: false),
        closeTo(-4.5678, 1e-9),
      );
    });

    test('reads a decimal comma in the minutes of a degree entry', () {
      expect(
        parseSingleAxis('48 30,5 0 N', isLatitude: true),
        closeTo(48 + 30.5 / 60, 1e-9),
      );
    });

    test('does not read a comma as degrees and minutes', () {
      // '4,5' once read as 4 degrees 5 minutes, which is a silent misread.
      expect(parseSingleAxis('4,5', isLatitude: false), closeTo(4.5, 1e-9));
    });
  });

  group('isDecimalCommaNumber', () {
    test('matches a single number written with a decimal comma', () {
      expect(isDecimalCommaNumber('48,8566'), isTrue);
      expect(isDecimalCommaNumber('-4,5678'), isTrue);
      expect(isDecimalCommaNumber(' 43,5 '), isTrue);
    });

    test('does not match a comma-separated coordinate pair', () {
      expect(isDecimalCommaNumber('20.361944, -87.029722'), isFalse);
      expect(isDecimalCommaNumber('20.5,87.3'), isFalse);
      expect(isDecimalCommaNumber('20, -87'), isFalse);
      expect(isDecimalCommaNumber('20,5 87,3'), isFalse);
    });

    test('matches a single axis with a hemisphere or degree sign', () {
      // '43,5 E' would otherwise reach the paste path, which reads it as the
      // pair (43, 5 E) and overwrites the other axis.
      expect(isDecimalCommaNumber('43,5 E'), isTrue);
      expect(isDecimalCommaNumber('N 48,8566°'), isTrue);
    });

    test('does not match a grid reference with a comma', () {
      // A comma-separated UTM pair is a whole position, not one axis.
      expect(isDecimalCommaNumber('16Q 496898,2251535'), isFalse);
      expect(isDecimalCommaNumber('20 87,3'), isFalse);
    });

    test('does not match text without a comma', () {
      expect(isDecimalCommaNumber('48.8566'), isFalse);
      expect(isDecimalCommaNumber(''), isFalse);
    });
  });
}
