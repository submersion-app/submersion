import 'dart:convert';
import 'dart:io' show Platform, HttpClient, SocketException;
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:submersion/core/services/geocoding/nominatim_throttle.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Check if we're on a mobile platform (iOS/Android)
bool get _isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

/// Nominatim answered with something other than 200. "Nothing here" is a
/// 200 with an error body, so a non-200 is the service itself (rate limit,
/// outage, blocked user agent), which callers must not mistake for "no
/// location details found".
class _NominatimStatusException implements Exception {
  const _NominatimStatusException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'Nominatim responded with HTTP $statusCode';
}

/// Result of a location capture
class LocationResult {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? country;
  final String? region;
  final String? locality;
  final String? bodyOfWater;

  /// True when the position was found but the geocoder could not be
  /// reached, so the empty place fields mean "unknown", not "nothing there".
  final bool geocodeUnavailable;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.country,
    this.region,
    this.locality,
    this.bodyOfWater,
    this.geocodeUnavailable = false,
  });

  /// The geocoded part of this result, in the shape the site form consumes.
  PlaceLookup get place => PlaceLookup(
    country: country,
    region: region,
    locality: locality,
    bodyOfWater: bodyOfWater,
    networkFailed: geocodeUnavailable,
  );

  @override
  String toString() =>
      'LocationResult(lat: $latitude, lng: $longitude, country: $country, region: $region)';
}

/// Service for handling device GPS location and geocoding
class LocationService {
  /// The language every existing row was geocoded in. Issue #214 pinned
  /// results to English because the platform geocoder answered in the device
  /// locale and split one country across 'Spanien' and 'España'. The pin is
  /// now a synced per-diver setting (issue #1187) whose default is this
  /// value, so unchanged users keep grouping exactly as before.
  static const String defaultLanguageCode = 'en';

  /// Nominatim reverse-geocode URI for the address layer. The language code
  /// is user data (a synced setting), so it is query-encoded rather than
  /// interpolated, which keeps a stray `&` from becoming a second parameter.
  static Uri buildReverseGeocodeUri(
    double latitude,
    double longitude, {
    required String languageCode,
  }) => Uri.parse(
    'https://nominatim.openstreetmap.org/reverse?format=json'
    '&lat=$latitude&lon=$longitude&zoom=10'
    '&accept-language=${Uri.encodeQueryComponent(languageCode)}',
  );

  /// Nominatim reverse-geocode URI for the natural layer, which answers with
  /// the lake, bay or strait a point lies in. zoom=14 keeps the answer to a
  /// named feature rather than the whole region. Nominatim has no ocean
  /// polygons, so open-sea points come back "Unable to geocode".
  static Uri buildNaturalFeatureUri(
    double latitude,
    double longitude, {
    required String languageCode,
  }) => Uri.parse(
    'https://nominatim.openstreetmap.org/reverse?format=json'
    '&lat=$latitude&lon=$longitude&zoom=14&layer=natural'
    '&accept-language=${Uri.encodeQueryComponent(languageCode)}',
  );

  /// The name of a water feature from a natural-layer answer, or null when
  /// the hit is not water. The natural layer also carries mountain ranges,
  /// saddles and peaks; class `water` covers lakes, reservoirs and rivers,
  /// and bays and straits arrive as class `natural`.
  static String? bodyOfWaterFromNaturalFeature(Map<String, dynamic> json) {
    final osmClass = json['class'] as String?;
    final type = json['type'] as String?;
    final name = (json['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    if (osmClass == 'water') return name;
    if (osmClass == 'natural' && (type == 'bay' || type == 'strait')) {
      return name;
    }
    return null;
  }

  /// Nominatim forward-geocode URI, English-pinned: dive centres are matched
  /// by address text, not grouped in statistics.
  static Uri buildForwardGeocodeUri(String address) => Uri.parse(
    'https://nominatim.openstreetmap.org/search?format=json'
    '&q=${Uri.encodeComponent(address)}&limit=1&addressdetails=1'
    '&accept-language=$defaultLanguageCode',
  );

  /// Routes reverse geocoding through the platform geocoder.
  ///
  /// True on mobile in production. `Platform.isIOS`/`isAndroid` are
  /// natively-resolved statics with no override hook, so the mobile branch
  /// is otherwise unreachable on a desktop test host -- including the
  /// English-locale contract below, the part of #214 most worth asserting.
  @visibleForTesting
  static bool debugForceNativeGeocoder = false;

  static bool get _useNativeGeocoder => debugForceNativeGeocoder || _isMobile;

  /// Process-wide spacing for every Nominatim request. Tests replace it with
  /// a zero-gap instance so lookups do not wait a real second each.
  @visibleForTesting
  static NominatimThrottle throttle = NominatimThrottle();

  static final _log = LoggerService.forClass(LocationService);
  static LocationService? _instance;

  LocationService._();

  static LocationService get instance {
    _instance ??= LocationService._();
    return _instance!;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current device location with optional reverse geocoding
  /// Returns null if permission denied or location unavailable
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = defaultLanguageCode,
  }) async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        _log.warning('Location services are disabled');
        return null;
      }

      // Check permission
      var permission = await checkPermission();
      final wasNewlyGranted = permission == LocationPermission.denied;
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          _log.warning('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _log.warning('Location permission permanently denied');
        return null;
      }

      // On macOS, Core Location needs time to initialize after a fresh
      // permission grant — the location daemon must start and WiFi
      // positioning must warm up before it can deliver a fix.
      if (wasNewlyGranted && !kIsWeb && Platform.isMacOS) {
        _log.info(
          'Fresh permission grant on macOS, waiting for CLLocationManager init...',
        );
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      // Use reduced accuracy on desktop (no GPS hardware — relies on WiFi
      // triangulation) to avoid timeouts waiting for precision that cannot
      // be achieved.
      final accuracy = _isMobile
          ? LocationAccuracy.high
          : LocationAccuracy.medium;

      // Get current position with retries. Desktop platforms (especially
      // macOS) often need multiple attempts as the location manager warms up.
      _log.info('Getting current device location (accuracy: $accuracy)...');
      Position? position;
      final maxAttempts = _isMobile ? 2 : 3;

      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: accuracy,
              timeLimit: timeout,
            ),
          );
          break;
        } catch (e) {
          _log.warning('Location attempt $attempt/$maxAttempts failed: $e');
          if (attempt < maxAttempts) {
            await Future<void>.delayed(Duration(seconds: attempt));
          }
        }
      }

      // Last resort: check for a cached position from a previous session
      if (position == null) {
        _log.info('Live positioning failed, trying last known position...');
        position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          _log.info(
            'Using last known position: ${position.latitude}, ${position.longitude}',
          );
        }
      }

      if (position == null) {
        _log.warning('All location attempts failed');
        return null;
      }

      _log.info(
        'Got position: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)',
      );

      PlaceLookup place = const PlaceLookup.empty();

      // Perform reverse geocoding if requested
      if (includeGeocoding) {
        place = await reverseGeocode(
          position.latitude,
          position.longitude,
          languageCode: languageCode,
        );
      }

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        country: place.country,
        region: place.region,
        locality: place.locality,
        bodyOfWater: place.bodyOfWater,
        geocodeUnavailable: place.networkFailed,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get current location',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Reverse geocode a coordinate into country, region and locality, in the
  /// language named by [languageCode] (an ISO 639-1 code such as 'en').
  ///
  /// Uses the platform geocoder on mobile and falls back to OpenStreetMap
  /// Nominatim everywhere else. Never throws: a geocoder that cannot be
  /// reached yields [PlaceLookup.unavailable].
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    try {
      _log.info('Reverse geocoding: $latitude, $longitude ($languageCode)');

      // Try native geocoding first (works on iOS/Android)
      if (_useNativeGeocoder) {
        try {
          // Built per call rather than cached in a static: construction only
          // asks the platform factory for an implementation, and a cached
          // instance would outlive the per-test factory fakes.
          final placemarks = await Geocoding().placemarkFromCoordinates(
            latitude,
            longitude,
            locale: Locale(languageCode),
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            _log.info(
              'Native geocoded: ${place.locality}, ${place.administrativeArea}, ${place.country}',
            );
            return await _withBodyOfWater(
              PlaceLookup(
                country: place.country,
                region: place.administrativeArea,
                locality: place.locality,
              ),
              latitude,
              longitude,
              languageCode,
            );
          }
        } catch (e) {
          _log.warning('Native geocoding failed, trying web fallback: $e');
        }
      }

      // Fallback to OpenStreetMap Nominatim API (works on all platforms)
      final address = await _reverseGeocodeWeb(
        latitude,
        longitude,
        languageCode,
      );
      if (address.networkFailed) return address;
      return await _withBodyOfWater(address, latitude, longitude, languageCode);
    } catch (e, stackTrace) {
      _log.error('Reverse geocoding failed', error: e, stackTrace: stackTrace);
      return const PlaceLookup.unavailable();
    }
  }

  /// Web-based reverse geocoding using OpenStreetMap Nominatim
  Future<PlaceLookup> _reverseGeocodeWeb(
    double latitude,
    double longitude,
    String languageCode,
  ) async {
    try {
      final json = await _fetchNominatimJson(
        buildReverseGeocodeUri(latitude, longitude, languageCode: languageCode),
        languageCode,
      );
      final address = json['address'] as Map<String, dynamic>?;
      if (address == null) return const PlaceLookup.empty();

      final country = address['country'] as String?;
      final region =
          address['state'] as String? ??
          address['province'] as String? ??
          address['region'] as String?;
      final locality =
          address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String?;

      _log.info('Web geocoded: $locality, $region, $country');
      return PlaceLookup(country: country, region: region, locality: locality);
    } on SocketException catch (e) {
      _log.warning('Web reverse geocoding unreachable: $e');
      return const PlaceLookup.unavailable();
    } on _NominatimStatusException catch (e) {
      _log.warning('Web reverse geocoding refused: $e');
      return const PlaceLookup.unavailable();
    } catch (e) {
      _log.warning('Web reverse geocoding failed: $e');
      return const PlaceLookup.empty();
    }
  }

  Future<PlaceLookup> _withBodyOfWater(
    PlaceLookup address,
    double latitude,
    double longitude,
    String languageCode,
  ) async {
    final water = await _lookupBodyOfWater(latitude, longitude, languageCode);
    return water == null ? address : address.copyWith(bodyOfWater: water);
  }

  /// Best-effort: any failure here leaves the address result untouched.
  Future<String?> _lookupBodyOfWater(
    double latitude,
    double longitude,
    String languageCode,
  ) async {
    try {
      final json = await _fetchNominatimJson(
        buildNaturalFeatureUri(latitude, longitude, languageCode: languageCode),
        languageCode,
      );
      final water = bodyOfWaterFromNaturalFeature(json);
      _log.info('Natural layer: ${water ?? 'no water feature'}');
      return water;
    } catch (e) {
      _log.warning('Body of water lookup failed: $e');
      return null;
    }
  }

  /// One Nominatim GET, decoded. Throws [_NominatimStatusException] on a
  /// non-200 status and lets socket errors propagate, so callers can tell
  /// "offline" and "refused" from "nothing there". The client is closed in a
  /// finally so its sockets are released even when the body or the JSON
  /// decode throws.
  Future<Map<String, dynamic>> _fetchNominatimJson(
    Uri url,
    String languageCode,
  ) async {
    await throttle.wait();
    final client = HttpClient();
    client.userAgent = 'Submersion Dive Log App';
    try {
      final request = await client.getUrl(url);
      request.headers.set('Accept-Language', languageCode);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw _NominatimStatusException(response.statusCode);
      }
      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Forward geocode an address to get coordinates
  /// Uses OpenStreetMap Nominatim API
  Future<LocationResult?> forwardGeocode(String address) async {
    if (address.trim().isEmpty) {
      return null;
    }

    try {
      _log.info('Forward geocoding address: $address');

      final url = buildForwardGeocodeUri(address);

      await throttle.wait();
      final client = HttpClient();
      client.userAgent = 'Submersion Dive Log App';

      // Close in a finally so the client's sockets are released even when
      // the response body or JSON decode throws.
      try {
        final request = await client.getUrl(url);
        request.headers.set('Accept-Language', 'en');
        final response = await request.close();

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as List<dynamic>;

          if (json.isNotEmpty) {
            final result = json.first as Map<String, dynamic>;
            final lat = double.tryParse(result['lat'] as String? ?? '');
            final lon = double.tryParse(result['lon'] as String? ?? '');

            if (lat != null && lon != null) {
              final addressDetails =
                  result['address'] as Map<String, dynamic>? ?? {};
              final country = addressDetails['country'] as String?;
              final region =
                  addressDetails['state'] as String? ??
                  addressDetails['province'] as String? ??
                  addressDetails['region'] as String?;
              final locality =
                  addressDetails['city'] as String? ??
                  addressDetails['town'] as String? ??
                  addressDetails['village'] as String?;

              _log.info(
                'Forward geocoded: $lat, $lon ($locality, $region, $country)',
              );
              return LocationResult(
                latitude: lat,
                longitude: lon,
                country: country,
                region: region,
                locality: locality,
              );
            }
          }
        }
      } finally {
        client.close();
      }

      _log.warning('Forward geocoding returned no results for: $address');
      return null;
    } catch (e, stackTrace) {
      _log.error('Forward geocoding failed', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Calculate distance between two points in meters
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Open device location settings (for when permission is permanently denied)
  /// Only works on iOS/Android
  Future<bool> openLocationSettings() async {
    if (!_isMobile) {
      _log.warning('openLocationSettings not supported on this platform');
      return false;
    }
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      _log.warning('Failed to open location settings: $e');
      return false;
    }
  }

  /// Open app settings (for when permission is permanently denied)
  /// Only works on iOS/Android
  Future<bool> openAppSettings() async {
    if (!_isMobile) {
      _log.warning('openAppSettings not supported on this platform');
      return false;
    }
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      _log.warning('Failed to open app settings: $e');
      return false;
    }
  }

  /// Check if GPS features are supported on this platform
  bool get isSupported =>
      _isMobile || Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
