import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/mgrs_converter.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  // Vectors from NGA GEOTRANS. Do not adjust to match code.
  const cases = <({String name, double lat, double lng, String mgrs})>[
    (
      name: 'Cozumel Palancar',
      lat: 20.361944,
      lng: -87.029722,
      mgrs: '16Q DH 96898 51535',
    ),
    (
      name: 'Blue Hole Belize',
      lat: 17.315833,
      lng: -87.535,
      mgrs: '16Q DE 43148 14573',
    ),
    (
      name: 'SS Yongala',
      lat: -19.305278,
      lng: 147.6225,
      mgrs: '55K EU 65398 65276',
    ),
    (
      name: 'Silfra',
      lat: 64.255833,
      lng: -21.123889,
      mgrs: '27W VM 93995 25528',
    ),
    (
      name: 'Blue Corner Palau',
      lat: 7.14,
      lng: 134.221667,
      mgrs: '53N MH 14055 89297',
    ),
    (name: 'Null Island', lat: 0.0, lng: 0.0, mgrs: '31N AA 66021 00000'),
    (name: 'Norway exception', lat: 60.0, lng: 5.0, mgrs: '32V KM 76979 58157'),
    (
      name: 'Svalbard exception',
      lat: 78.0,
      lng: 20.0,
      mgrs: '33X XG 15914 63320',
    ),
    (name: 'Otago NZ', lat: -45.5, lng: 170.5, mgrs: '59G MK 60936 61381'),
  ];

  group('latLngToMgrs', () {
    for (final c in cases) {
      test('${c.name} matches the reference grid reference', () {
        expect(latLngToMgrs(c.lat, c.lng), c.mgrs);
      });
    }

    test(
      'truncates rather than rounds, because a reference names a square',
      () {
        // Blue Hole's true UTM northing is 1914573.6. Rounding would give
        // ...14574; the south-west corner convention requires ...14573.
        expect(latLngToMgrs(17.315833, -87.535), endsWith('14573'));
      },
    );

    test('returns null outside the UTM band', () {
      expect(latLngToMgrs(85.0, 10.0), isNull);
    });
  });

  group('mgrsToLatLng', () {
    for (final c in cases) {
      test('${c.name} round-trips to within two metres', () {
        final back = mgrsToLatLng(c.mgrs)!;
        // Truncation to the square's south-west corner costs up to 1 m per
        // axis, so a 2 m ground bound is the honest limit.
        final error = distanceMeters(
          GeoPoint(c.lat, c.lng),
          GeoPoint(back.latitude, back.longitude),
        );
        expect(error, lessThan(2.0));
      });
    }

    test('accepts a run-together reference, as printed on maps', () {
      final back = mgrsToLatLng('16QDH9689851535')!;
      final error = distanceMeters(
        const GeoPoint(20.361944, -87.029722),
        GeoPoint(back.latitude, back.longitude),
      );
      expect(error, lessThan(2.0));
    });

    test('accepts lowercase', () {
      expect(mgrsToLatLng('16qdh9689851535'), isNotNull);
    });

    test('rejects malformed references', () {
      expect(mgrsToLatLng('not a grid reference'), isNull);
      expect(mgrsToLatLng('16Q DH 96898'), isNull); // odd digit count
      expect(mgrsToLatLng('16I DH 96898 51535'), isNull); // I is not a band
    });
  });
}
