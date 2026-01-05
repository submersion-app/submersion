import 'dart:convert';
import 'dart:io' show Platform, HttpClient;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'logger_service.dart';

/// Check if we're on a mobile platform (iOS/Android)
bool get _isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

/// Result of a location capture
class LocationResult {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? country;
  final String? region;
  final String? locality;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.country,
    this.region,
    this.locality,
  });

  @override
  String toString() =>
      'LocationResult(lat: $latitude, lng: $longitude, country: $country, region: $region)';
}

/// Service for handling device GPS location and geocoding
class LocationService {
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

      // Get current position
      _log.info('Getting current device location...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      _log.info(
        'Got position: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)',
      );

      String? country;
      String? region;
      String? locality;

      // Perform reverse geocoding if requested
      if (includeGeocoding) {
        final geocodeResult = await reverseGeocode(
          position.latitude,
          position.longitude,
        );
        country = geocodeResult.country;
        region = geocodeResult.region;
        locality = geocodeResult.locality;
      }

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        country: country,
        region: region,
        locality: locality,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get current location', e, stackTrace);
      return null;
    }
  }

  /// Reverse geocode a location to get country/region
  /// Uses native geocoding on mobile, falls back to OpenStreetMap Nominatim on desktop
  Future<({String? country, String? region, String? locality})> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      _log.info('Reverse geocoding: $latitude, $longitude');

      // Try native geocoding first (works on iOS/Android)
      if (_isMobile) {
        try {
          final placemarks = await placemarkFromCoordinates(
            latitude,
            longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            _log.info(
              'Native geocoded: ${place.locality}, ${place.administrativeArea}, ${place.country}',
            );
            return (
              country: place.country,
              region: place.administrativeArea,
              locality: place.locality,
            );
          }
        } catch (e) {
          _log.warning('Native geocoding failed, trying web fallback: $e');
        }
      }

      // Fallback to OpenStreetMap Nominatim API (works on all platforms)
      return await _reverseGeocodeWeb(latitude, longitude);
    } catch (e, stackTrace) {
      _log.error('Reverse geocoding failed', e, stackTrace);
      return (country: null, region: null, locality: null);
    }
  }

  /// Web-based reverse geocoding using OpenStreetMap Nominatim
  Future<({String? country, String? region, String? locality})>
  _reverseGeocodeWeb(double latitude, double longitude) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=10',
      );

      final client = HttpClient();
      client.userAgent = 'Submersion Dive Log App';

      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final address = json['address'] as Map<String, dynamic>?;

        if (address != null) {
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
          return (country: country, region: region, locality: locality);
        }
      }

      return (country: null, region: null, locality: null);
    } catch (e) {
      _log.warning('Web reverse geocoding failed: $e');
      return (country: null, region: null, locality: null);
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
