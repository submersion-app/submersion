import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
// `geocoding` declares its own app-facing `Geocoding`, which shadows the
// platform-interface class of the same name that fakes must extend.
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart'
    as gpi;
import 'package:submersion/core/services/geocoding/nominatim_throttle.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';

import '../../helpers/fake_nominatim.dart';

void main() {
  final service = LocationService.instance;

  setUp(() {
    LocationService.throttle = NominatimThrottle(minimumGap: Duration.zero);
    addTearDown(() => LocationService.throttle = NominatimThrottle());
  });

  group('Nominatim URIs pin English results (#214)', () {
    test('reverse geocode URI carries the requested accept-language', () {
      final uri = LocationService.buildReverseGeocodeUri(
        36.0,
        -5.6,
        languageCode: 'fr',
      );
      expect(
        uri.queryParameters['accept-language'],
        'fr',
        reason:
            'without a pinned language Nominatim answers in the request '
            'locale, splitting statistics into Spain/Spanien/España rows',
      );
      expect(uri.queryParameters['lat'], '36.0');
      expect(uri.queryParameters['lon'], '-5.6');
    });

    test('the language code is query-encoded, never interpolated', () {
      // The code is synced user data; a stray separator must not become a
      // second query parameter.
      for (final uri in [
        LocationService.buildReverseGeocodeUri(
          36.0,
          -5.6,
          languageCode: 'en&foo=bar',
        ),
        LocationService.buildNaturalFeatureUri(
          36.0,
          -5.6,
          languageCode: 'en&foo=bar',
        ),
      ]) {
        expect(uri.queryParameters['accept-language'], 'en&foo=bar');
        expect(uri.queryParameters.containsKey('foo'), isFalse);
      }
    });

    test('forward geocode URI carries accept-language=en', () {
      final uri = LocationService.buildForwardGeocodeUri('Blue Hole');
      expect(uri.queryParameters['accept-language'], 'en');
      expect(uri.queryParameters['q'], 'Blue Hole');
    });
  });

  group('reverseGeocode web fallback', () {
    test(
      'parses country, region and locality from a Nominatim response',
      () async {
        final server = FakeNominatim(
          body: jsonEncode(<String, dynamic>{
            'address': <String, dynamic>{
              'country': 'Spain',
              'state': 'Andalusia',
              'city': 'Tarifa',
            },
          }),
        );

        final result = await server.run(
          () => service.reverseGeocode(36.0143, -5.6044, languageCode: 'en'),
        );

        expect(result.country, 'Spain');
        expect(result.region, 'Andalusia');
        expect(result.locality, 'Tarifa');
      },
    );

    test(
      'sends the English pin in both the URI and the request headers',
      () async {
        final server = FakeNominatim(
          body: jsonEncode(<String, dynamic>{
            'address': <String, dynamic>{'country': 'Spain'},
          }),
        );

        await server.run(
          () => service.reverseGeocode(36.0143, -5.6044, languageCode: 'en'),
        );

        expect(server.requestedUris, hasLength(2));
        expect(
          server.requestedUris.first.queryParameters['accept-language'],
          'en',
          reason: 'the request itself must carry the pin, not just the builder',
        );
        expect(
          server.lastHeaders['accept-language'],
          'en',
          reason:
              'Nominatim honours the Accept-Language header over the query '
              'parameter, so both have to say en (#214)',
        );
        expect(
          server.lastUri.host,
          'nominatim.openstreetmap.org',
          reason: 'the fake must have intercepted the real endpoint',
        );
      },
    );

    test('sends the requested language in the URI and the headers', () async {
      final server = FakeNominatim(
        body: jsonEncode(<String, dynamic>{
          'address': <String, dynamic>{'country': 'Schweiz'},
        }),
      );

      final result = await server.run(
        () => service.reverseGeocode(47.0276, 8.4006, languageCode: 'de'),
      );

      expect(result.country, 'Schweiz');
      expect(server.lastUri.queryParameters['accept-language'], 'de');
      expect(server.lastHeaders['accept-language'], 'de');
    });

    test('returns PlaceLookup.unavailable when the request throws', () async {
      final result = await HttpOverrides.runZoned(
        () => service.reverseGeocode(47.0, 8.4, languageCode: 'en'),
        createHttpClient: (_) => ThrowingHttpClient(),
      );

      expect(result.isEmpty, isTrue);
      expect(result.networkFailed, isTrue);
    });

    test('falls back from state to province for the region', () async {
      final server = FakeNominatim(
        body: jsonEncode(<String, dynamic>{
          'address': <String, dynamic>{
            'country': 'Canada',
            'province': 'Ontario',
            'town': 'Tobermory',
          },
        }),
      );

      final result = await server.run(
        () => service.reverseGeocode(45.2542, -81.6653, languageCode: 'en'),
      );

      expect(result.region, 'Ontario');
      expect(result.locality, 'Tobermory', reason: 'town backs up city');
    });

    test('falls back from province to region, and to village', () async {
      final server = FakeNominatim(
        body: jsonEncode(<String, dynamic>{
          'address': <String, dynamic>{
            'country': 'Egypt',
            'region': 'Red Sea',
            'village': 'Dahab',
          },
        }),
      );

      final result = await server.run(
        () => service.reverseGeocode(28.5091, 34.5136, languageCode: 'en'),
      );

      expect(result.country, 'Egypt');
      expect(result.region, 'Red Sea');
      expect(result.locality, 'Dahab');
    });

    test(
      'returns empty fields when the payload has no address block',
      () async {
        final server = FakeNominatim(
          body: jsonEncode(<String, dynamic>{'error': 'Unable to geocode'}),
        );

        final result = await server.run(
          () => service.reverseGeocode(0.0, 0.0, languageCode: 'en'),
        );

        expect(result.country, isNull);
        expect(result.region, isNull);
        expect(result.locality, isNull);
      },
    );

    test('reports the geocoder as unavailable on a non-200 response', () async {
      // Nominatim says "nothing here" with a 200 and an error body, so a
      // non-200 is the service itself: a rate limit or an outage, which must
      // not read as "no location details found" (and must not count as
      // unchanged in the bulk backfill).
      final server = FakeNominatim(
        statusCode: 503,
        body: 'Service Unavailable',
      );

      final result = await server.run(
        () => service.reverseGeocode(36.0143, -5.6044, languageCode: 'en'),
      );

      expect(result.isEmpty, isTrue);
      expect(result.networkFailed, isTrue);
    });

    test('a rate limit is reported the same way', () async {
      final server = FakeNominatim(statusCode: 429, body: 'Too Many Requests');

      final result = await server.run(
        () => service.reverseGeocode(36.0143, -5.6044, languageCode: 'en'),
      );

      expect(result.networkFailed, isTrue);
    });

    test('swallows malformed JSON instead of throwing', () async {
      final server = FakeNominatim(body: '<html>rate limited</html>');

      final result = await server.run(
        () => service.reverseGeocode(36.0143, -5.6044, languageCode: 'en'),
      );

      expect(result.country, isNull);
      expect(result.region, isNull);
      expect(result.locality, isNull);
    });

    test('closes the HttpClient even when the body fails to parse', () async {
      final server = FakeNominatim(body: 'not json');

      await server.run(
        () => service.reverseGeocode(36.0143, -5.6044, languageCode: 'en'),
      );

      expect(
        server.clientCloseCount,
        server.requestedUris.length,
        reason:
            'the finally block must release the sockets on the error path, '
            'once per request (address layer, then natural layer)',
      );
    });
  });

  group('forwardGeocode', () {
    test('returns the parsed coordinates and address details', () async {
      final server = FakeNominatim(
        body: jsonEncode(<dynamic>[
          <String, dynamic>{
            'lat': '36.0143',
            'lon': '-5.6044',
            'address': <String, dynamic>{
              'country': 'Spain',
              'state': 'Andalusia',
              'city': 'Tarifa',
            },
          },
        ]),
      );

      final result = await server.run(() => service.forwardGeocode('Tarifa'));

      expect(result, isNotNull);
      expect(result!.latitude, closeTo(36.0143, 1e-9));
      expect(result.longitude, closeTo(-5.6044, 1e-9));
      expect(result.country, 'Spain');
      expect(result.region, 'Andalusia');
      expect(result.locality, 'Tarifa');
      expect(result.accuracy, isNull);
    });

    test(
      'sends the English pin in both the URI and the request headers',
      () async {
        final server = FakeNominatim(
          body: jsonEncode(<dynamic>[
            <String, dynamic>{'lat': '36.0143', 'lon': '-5.6044'},
          ]),
        );

        await server.run(() => service.forwardGeocode('Blue Hole'));

        expect(server.requestedUris, hasLength(1));
        expect(server.lastUri.queryParameters['accept-language'], 'en');
        expect(server.lastUri.queryParameters['q'], 'Blue Hole');
        expect(server.lastHeaders['accept-language'], 'en');
      },
    );

    test('falls back from state to province, and from city to town', () async {
      final server = FakeNominatim(
        body: jsonEncode(<dynamic>[
          <String, dynamic>{
            'lat': '45.2542',
            'lon': '-81.6653',
            'address': <String, dynamic>{
              'country': 'Canada',
              'province': 'Ontario',
              'town': 'Tobermory',
            },
          },
        ]),
      );

      final result = await server.run(
        () => service.forwardGeocode('Tobermory'),
      );

      expect(result!.region, 'Ontario');
      expect(result.locality, 'Tobermory');
    });

    test('falls back to region and village as the last options', () async {
      final server = FakeNominatim(
        body: jsonEncode(<dynamic>[
          <String, dynamic>{
            'lat': '28.5091',
            'lon': '34.5136',
            'address': <String, dynamic>{
              'country': 'Egypt',
              'region': 'Red Sea',
              'village': 'Dahab',
            },
          },
        ]),
      );

      final result = await server.run(() => service.forwardGeocode('Dahab'));

      expect(result!.region, 'Red Sea');
      expect(result.locality, 'Dahab');
    });

    test(
      'returns coordinates with null details when address is absent',
      () async {
        final server = FakeNominatim(
          body: jsonEncode(<dynamic>[
            <String, dynamic>{'lat': '12.5', 'lon': '-70.0'},
          ]),
        );

        final result = await server.run(() => service.forwardGeocode('Aruba'));

        expect(result!.latitude, closeTo(12.5, 1e-9));
        expect(result.longitude, closeTo(-70.0, 1e-9));
        expect(result.country, isNull);
        expect(result.region, isNull);
        expect(result.locality, isNull);
      },
    );

    test('returns null when Nominatim has no match', () async {
      final server = FakeNominatim(body: '[]');

      final result = await server.run(
        () => service.forwardGeocode('Nowhere At All'),
      );

      expect(result, isNull);
    });

    test('returns null when the coordinates are not parseable', () async {
      final server = FakeNominatim(
        body: jsonEncode(<dynamic>[
          <String, dynamic>{'lat': 'not-a-number', 'lon': '-5.6044'},
        ]),
      );

      final result = await server.run(() => service.forwardGeocode('Tarifa'));

      expect(result, isNull);
    });

    test('returns null on a non-200 response', () async {
      final server = FakeNominatim(statusCode: 429, body: 'Too Many Requests');

      final result = await server.run(() => service.forwardGeocode('Tarifa'));

      expect(result, isNull);
      expect(
        server.clientCloseCount,
        1,
        reason: 'the client is closed even when the request is rejected',
      );
    });

    test('swallows malformed JSON instead of throwing', () async {
      final server = FakeNominatim(body: '<html>rate limited</html>');

      final result = await server.run(() => service.forwardGeocode('Tarifa'));

      expect(result, isNull);
    });

    test(
      'short-circuits a blank address without hitting the network',
      () async {
        final server = FakeNominatim(body: '[]');

        final result = await server.run(() => service.forwardGeocode('   '));

        expect(result, isNull);
        expect(
          server.requestedUris,
          isEmpty,
          reason: 'an empty query must never reach Nominatim',
        );
      },
    );
  });

  group('native geocoder locale (#214)', () {
    setUp(() {
      LocationService.debugForceNativeGeocoder = true;
    });

    tearDown(() {
      LocationService.debugForceNativeGeocoder = false;
    });

    test('asks the geocoder for the requested language', () async {
      final geocoding = _FakeGeocoding(
        placemarks: const [
          Placemark(
            country: 'Spain',
            administrativeArea: 'Andalusia',
            locality: 'Tarifa',
          ),
        ],
      );
      GeocodingPlatformFactory.instance = _FakeGeocodingFactory(geocoding);

      final result = await service.reverseGeocode(
        36.0143,
        -5.6044,
        languageCode: 'es',
      );

      expect(geocoding.locales, [const Locale('es')]);
      expect(result.country, 'Spain');
      expect(result.region, 'Andalusia');
      expect(result.locality, 'Tarifa');
    });

    test('every lookup carries the English locale', () async {
      final geocoding = _FakeGeocoding(
        placemarks: const [Placemark(country: 'Spain')],
      );
      GeocodingPlatformFactory.instance = _FakeGeocodingFactory(geocoding);

      await Future.wait([
        service.reverseGeocode(36.0, -5.6, languageCode: 'en'),
        service.reverseGeocode(37.0, -5.7, languageCode: 'en'),
        service.reverseGeocode(38.0, -5.8, languageCode: 'en'),
      ]);

      expect(
        geocoding.locales,
        [const Locale('en'), const Locale('en'), const Locale('en')],
        reason:
            'geocoding 5 resolves the locale per call, so unlike the old '
            'pin-once memo no later caller can inherit an unpinned geocoder',
      );
    });

    test('a failing native lookup falls back to the web geocoder', () async {
      final geocoding = _FakeGeocoding(
        placemarks: const [Placemark(country: 'Spain')],
        failOnce: true,
      );
      GeocodingPlatformFactory.instance = _FakeGeocodingFactory(geocoding);

      // The first attempt throws inside the native branch; the service falls
      // through to the web fallback rather than surfacing the failure.
      final server = FakeNominatim(
        body: '{"address": {"country": "Fallback"}}',
      );
      final first = await server.run(
        () => service.reverseGeocode(36.0, -5.6, languageCode: 'en'),
      );
      expect(
        first.country,
        'Fallback',
        reason: 'a native geocoder failure is non-fatal',
      );

      final second = await service.reverseGeocode(
        36.0,
        -5.6,
        languageCode: 'en',
      );

      expect(
        second.country,
        'Spain',
        reason: 'a later lookup retries the native geocoder',
      );
      expect(geocoding.locales, [const Locale('en'), const Locale('en')]);
    });
  });

  group('LocationResult.place', () {
    test('carries the geocoder outage through to the site form', () {
      const result = LocationResult(
        latitude: 47.0,
        longitude: 8.4,
        geocodeUnavailable: true,
      );
      expect(result.place.networkFailed, isTrue);
      expect(result.place.isEmpty, isTrue);
    });

    test('a geocoded result is a plain lookup', () {
      const result = LocationResult(
        latitude: 47.0,
        longitude: 8.4,
        country: 'Switzerland',
        locality: 'Weggis',
        bodyOfWater: 'Lake Lucerne',
      );
      expect(result.place.networkFailed, isFalse);
      expect(result.place.country, 'Switzerland');
      expect(result.place.locality, 'Weggis');
      expect(result.place.bodyOfWater, 'Lake Lucerne');
    });
  });

  group('body of water (issue #1187)', () {
    Map<String, dynamic> address() => <String, dynamic>{
      'address': <String, dynamic>{
        'country': 'Switzerland',
        'state': 'Lucerne',
        'village': 'Weggis',
      },
    };

    String? natural(Uri uri, Map<String, dynamic> hit) =>
        uri.queryParameters['layer'] == 'natural' ? jsonEncode(hit) : null;

    test('the natural-layer URI asks for water features only', () {
      final uri = LocationService.buildNaturalFeatureUri(
        47.027631,
        8.400640,
        languageCode: 'de',
      );
      expect(uri.host, 'nominatim.openstreetmap.org');
      expect(uri.path, '/reverse');
      expect(uri.queryParameters['layer'], 'natural');
      expect(uri.queryParameters['zoom'], '14');
      expect(uri.queryParameters['accept-language'], 'de');
      expect(uri.queryParameters['format'], 'json');
    });

    test('a lake on the natural layer becomes the body of water', () async {
      final server = FakeNominatim(
        body: jsonEncode(address()),
        bodyFor: (uri) => natural(uri, {
          'class': 'water',
          'type': 'lake',
          'name': 'Lake Lucerne',
        }),
      );

      final result = await server.run(
        () => service.reverseGeocode(47.027631, 8.400640, languageCode: 'en'),
      );

      expect(result.locality, 'Weggis');
      expect(result.bodyOfWater, 'Lake Lucerne');
      expect(server.requestedUris, hasLength(2));
      expect(server.requestedUris.last.queryParameters['layer'], 'natural');
    });

    test('a bay is accepted', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'class': 'natural',
          'type': 'bay',
          'name': 'Naama Bay',
        }),
        'Naama Bay',
      );
    });

    test('a strait is accepted', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'class': 'natural',
          'type': 'strait',
          'name': 'Strait of Gibraltar',
        }),
        'Strait of Gibraltar',
      );
    });

    test('a mountain range is not a body of water', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'class': 'natural',
          'type': 'mountain_range',
          'name': 'Urner Alps',
        }),
        isNull,
      );
    });

    test('a saddle is not a body of water', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'class': 'natural',
          'type': 'saddle',
          'name': 'coll Roig',
        }),
        isNull,
      );
    });

    test('an unable-to-geocode answer yields no body of water', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'error': 'Unable to geocode',
        }),
        isNull,
      );
    });

    test('a water hit with a blank name is ignored', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'class': 'water',
          'type': 'lake',
          'name': '',
        }),
        isNull,
      );
    });

    test('a non-200 on the natural layer keeps the address result', () async {
      final server = FakeNominatim(
        body: jsonEncode(address()),
        statusFor: (uri) =>
            uri.queryParameters['layer'] == 'natural' ? 503 : null,
      );

      final result = await server.run(
        () => service.reverseGeocode(47.027631, 8.400640, languageCode: 'en'),
      );

      expect(result.country, 'Switzerland');
      expect(result.bodyOfWater, isNull);
      expect(result.networkFailed, isFalse);
    });

    test('a failing natural-layer request keeps the address result', () async {
      var calls = 0;
      final server = FakeNominatim(
        body: jsonEncode(address()),
        bodyFor: (uri) {
          if (uri.queryParameters['layer'] != 'natural') return null;
          calls++;
          return 'this is not json';
        },
      );

      final result = await server.run(
        () => service.reverseGeocode(47.027631, 8.400640, languageCode: 'en'),
      );

      expect(calls, 1);
      expect(result.country, 'Switzerland');
      expect(result.locality, 'Weggis');
      expect(result.bodyOfWater, isNull);
      expect(result.networkFailed, isFalse);
    });

    test('the address and natural requests are a second apart', () {
      fakeAsync((async) {
        LocationService.throttle = NominatimThrottle();
        final start = clock.now();
        final seenAt = <Duration>[];
        final server = FakeNominatim(
          body: jsonEncode(address()),
          bodyFor: (uri) {
            seenAt.add(clock.now().difference(start));
            return uri.queryParameters['layer'] == 'natural'
                ? jsonEncode({'class': 'water', 'type': 'lake', 'name': 'L'})
                : null;
          },
        );
        PlaceLookup? result;
        server
            .run(() => service.reverseGeocode(47.0, 8.4, languageCode: 'en'))
            .then((r) => result = r);
        async.elapse(const Duration(seconds: 1));
        expect(seenAt, [Duration.zero, const Duration(seconds: 1)]);
        expect(result?.bodyOfWater, 'L');
      });
    });
  });
}

/// Minimal [GeocodingPlatformFactory] handing out one fake [gpi.Geocoding].
class _FakeGeocodingFactory extends GeocodingPlatformFactory {
  _FakeGeocodingFactory(this.geocoding);

  final _FakeGeocoding geocoding;

  @override
  gpi.Geocoding createGeocoding(GeocodingCreationParams params) => geocoding;
}

/// Minimal geocoder that records the locale each lookup asked for.
class _FakeGeocoding extends gpi.Geocoding {
  _FakeGeocoding({required this.placemarks, this.failOnce = false})
    : super.implementation(const GeocodingCreationParams());

  final List<Placemark> placemarks;
  bool failOnce;

  final List<Locale?> locales = <Locale?>[];

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    Locale? locale,
  }) async {
    locales.add(locale);
    if (failOnce) {
      failOnce = false;
      throw StateError('geocoder unavailable');
    }
    return placemarks;
  }
}
