import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/core/utils/coordinates/coordinate_formatter.dart';

void main() {
  // Pin the locale so decimal separators do not vary by host, following the
  // convention in the other unit-formatter tests.
  setUp(() => Intl.defaultLocale = 'en_US');

  const cases =
      <
        ({
          String name,
          double lat,
          double lng,
          String dd,
          String ddm,
          String dms,
          String utm,
          String mgrs,
        })
      >[
        (
          name: 'Cozumel Palancar',
          lat: 20.361944,
          lng: -87.029722,
          dd: '20.361944° N, 87.029722° W',
          ddm: "20° 21.717' N, 87° 01.783' W",
          dms: '20° 21\' 43.0" N, 87° 01\' 47.0" W',
          utm: '16Q 496898E 2251535N',
          mgrs: '16Q DH 96898 51535',
        ),
        (
          name: 'SS Yongala',
          lat: -19.305278,
          lng: 147.6225,
          dd: '19.305278° S, 147.622500° E',
          ddm: "19° 18.317' S, 147° 37.350' E",
          dms: '19° 18\' 19.0" S, 147° 37\' 21.0" E',
          utm: '55K 565399E 7865276N',
          mgrs: '55K EU 65398 65276',
        ),
        (
          name: 'Null Island',
          lat: 0.0,
          lng: 0.0,
          dd: '0.000000° N, 0.000000° E',
          ddm: "0° 00.000' N, 0° 00.000' E",
          dms: '0° 00\' 00.0" N, 0° 00\' 00.0" E',
          utm: '31N 166021E 0N',
          mgrs: '31N AA 66021 00000',
        ),
      ];

  for (final c in cases) {
    group(c.name, () {
      test('decimal degrees', () {
        expect(
          formatCoordinates(c.lat, c.lng, CoordinateFormat.decimalDegrees),
          c.dd,
        );
      });
      test('degrees decimal minutes', () {
        expect(
          formatCoordinates(
            c.lat,
            c.lng,
            CoordinateFormat.degreesDecimalMinutes,
          ),
          c.ddm,
        );
      });
      test('degrees minutes seconds', () {
        expect(
          formatCoordinates(
            c.lat,
            c.lng,
            CoordinateFormat.degreesMinutesSeconds,
          ),
          c.dms,
        );
      });
      test('utm', () {
        expect(formatCoordinates(c.lat, c.lng, CoordinateFormat.utm), c.utm);
      });
      test('mgrs', () {
        expect(formatCoordinates(c.lat, c.lng, CoordinateFormat.mgrs), c.mgrs);
      });
    });
  }

  test('a polar coordinate falls back to decimal degrees', () {
    // UTM is undefined above 84 N, so the grid formats degrade rather than
    // showing a wrong or empty reference.
    expect(
      formatCoordinates(85.5, 10.0, CoordinateFormat.mgrs),
      formatCoordinates(85.5, 10.0, CoordinateFormat.decimalDegrees),
    );
    expect(
      formatCoordinates(85.5, 10.0, CoordinateFormat.utm),
      formatCoordinates(85.5, 10.0, CoordinateFormat.decimalDegrees),
    );
  });

  test('seconds carry into minutes rather than showing 60', () {
    final text = formatLatitude(
      0.9999999999,
      CoordinateFormat.degreesMinutesSeconds,
    );
    expect(text, isNot(contains('60.0"')));
    expect(text, '1° 00\' 00.0" N');
  });

  test('minutes carry into degrees rather than showing 60', () {
    final text = formatLatitude(
      0.9999999999,
      CoordinateFormat.degreesDecimalMinutes,
    );
    expect(text, isNot(contains('60.000')));
    expect(text, "1° 00.000' N");
  });

  group('single-axis formatting', () {
    test('renders one axis for the degree family', () {
      expect(
        formatLatitude(20.361944, CoordinateFormat.decimalDegrees),
        '20.361944° N',
      );
      expect(
        formatLongitude(-87.029722, CoordinateFormat.degreesDecimalMinutes),
        "87° 01.783' W",
      );
    });

    test('degrades grid formats to decimal degrees, since one axis of a '
        'grid reference means nothing', () {
      expect(formatLatitude(20.361944, CoordinateFormat.mgrs), '20.361944° N');
    });
  });
}
