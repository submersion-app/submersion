import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/utm_converter.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  // Vectors generated from NGA GEOTRANS. Do not adjust to match code.
  const cases =
      <
        ({
          String name,
          double lat,
          double lng,
          int zone,
          String band,
          int easting,
          int northing,
        })
      >[
        (
          name: 'Cozumel Palancar',
          lat: 20.361944,
          lng: -87.029722,
          zone: 16,
          band: 'Q',
          easting: 496898,
          northing: 2251535,
        ),
        (
          name: 'Blue Hole Belize',
          lat: 17.315833,
          lng: -87.535,
          zone: 16,
          band: 'Q',
          easting: 443148,
          northing: 1914574,
        ),
        (
          name: 'SS Yongala',
          lat: -19.305278,
          lng: 147.6225,
          zone: 55,
          band: 'K',
          easting: 565399,
          northing: 7865276,
        ),
        (
          name: 'Silfra',
          lat: 64.255833,
          lng: -21.123889,
          zone: 27,
          band: 'W',
          easting: 493996,
          northing: 7125529,
        ),
        (
          name: 'Blue Corner Palau',
          lat: 7.14,
          lng: 134.221667,
          zone: 53,
          band: 'N',
          easting: 414056,
          northing: 789298,
        ),
        (
          name: 'Null Island',
          lat: 0.0,
          lng: 0.0,
          zone: 31,
          band: 'N',
          easting: 166021,
          northing: 0,
        ),
        (
          name: 'Norway exception',
          lat: 60.0,
          lng: 5.0,
          zone: 32,
          band: 'V',
          easting: 276980,
          northing: 6658157,
        ),
        (
          name: 'Svalbard exception',
          lat: 78.0,
          lng: 20.0,
          zone: 33,
          band: 'X',
          easting: 615915,
          northing: 8663320,
        ),
        (
          name: 'Otago NZ',
          lat: -45.5,
          lng: 170.5,
          zone: 59,
          band: 'G',
          easting: 460937,
          northing: 4961382,
        ),
      ];

  group('latLngToUtm', () {
    for (final c in cases) {
      test('${c.name} projects to the reference easting and northing', () {
        final utm = latLngToUtm(c.lat, c.lng)!;
        expect(utm.zone, c.zone);
        expect(utm.band, c.band);
        expect(utm.easting.round(), c.easting);
        expect(utm.northing.round(), c.northing);
      });
    }

    test('southern latitudes carry the 10 000 km false northing', () {
      expect(latLngToUtm(-19.305278, 147.6225)!.northing, greaterThan(7000000));
    });

    test('returns null above the UTM band, where UPS takes over', () {
      expect(latLngToUtm(85.0, 10.0), isNull);
      expect(latLngToUtm(-81.0, 10.0), isNull);
    });
  });

  group('utmToLatLng', () {
    for (final c in cases) {
      test('${c.name} round-trips to within a centimetre', () {
        final utm = latLngToUtm(c.lat, c.lng)!;
        final back = utmToLatLng(utm.zone, utm.band, utm.easting, utm.northing);
        // Measured on the ground, not in degrees: a degree of longitude
        // shrinks by cos(latitude), so a fixed degree tolerance would demand
        // five times the precision at Svalbard that it does at the equator.
        final error = distanceMeters(
          GeoPoint(c.lat, c.lng),
          GeoPoint(back.latitude, back.longitude),
        );
        expect(error, lessThan(0.01));
      });
    }
  });

  group('zone exceptions', () {
    test('southern Norway widens zone 32 westward', () {
      expect(utmZoneFor(60.0, 5.0), 32);
      // Just outside the exception box the ordinary rule applies.
      expect(utmZoneFor(55.0, 5.0), 31);
    });

    test('Svalbard reassigns four zones, not one', () {
      expect(utmZoneFor(78.0, 5.0), 31);
      expect(utmZoneFor(78.0, 20.0), 33);
      expect(utmZoneFor(78.0, 25.0), 35);
      expect(utmZoneFor(78.0, 35.0), 37);
    });
  });
}
