import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';

/// A dive center result from the bundled database.
class ExternalDiveCenter {
  final String externalId;
  final String name;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final List<String> affiliations;
  final String type; // center, shop, club
  final String source;

  const ExternalDiveCenter({
    required this.externalId,
    required this.name,
    this.location,
    this.latitude,
    this.longitude,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.affiliations = const [],
    this.type = 'center',
    required this.source,
  });

  /// Whether this center has valid coordinates.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Convert to a DiveCenter entity for import.
  DiveCenter toDiveCenter({String? diverId}) {
    final now = DateTime.now();
    return DiveCenter(
      id: '',
      diverId: diverId,
      name: name,
      location: location,
      latitude: latitude,
      longitude: longitude,
      country: country,
      phone: phone,
      email: email,
      website: website,
      affiliations: affiliations,
      notes: 'Imported from $source',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get type display name
  String get typeDisplay {
    switch (type) {
      case 'shop':
        return 'Dive Shop';
      case 'club':
        return 'Dive Club';
      default:
        return 'Dive Center';
    }
  }
}

/// Search result from the dive center service.
class DiveCenterSearchResult {
  final List<ExternalDiveCenter> centers;
  final int totalResults;
  final bool hasMore;
  final String? errorMessage;

  const DiveCenterSearchResult({
    required this.centers,
    this.totalResults = 0,
    this.hasMore = false,
    this.errorMessage,
  });

  factory DiveCenterSearchResult.error(String message) {
    return DiveCenterSearchResult(centers: [], errorMessage: message);
  }

  bool get isSuccess => errorMessage == null;
}

/// Service for searching dive centers from the bundled database.
class DiveCenterApiService {
  static final _log = LoggerService.forClass(DiveCenterApiService);

  /// Cached bundled dive centers to avoid reloading.
  List<ExternalDiveCenter>? _bundledCenters;

  /// Search for dive centers by query string.
  Future<DiveCenterSearchResult> searchCenters(String query) async {
    if (query.trim().isEmpty) {
      return const DiveCenterSearchResult(centers: []);
    }
    return _searchBundledCenters(query);
  }

  /// Search for dive centers near coordinates.
  Future<DiveCenterSearchResult> searchNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
  }) async {
    return _searchNearbyBundled(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
  }

  /// Search for dive centers by country.
  Future<DiveCenterSearchResult> searchByCountry(String country) async {
    return _searchBundledCenters(country);
  }

  /// Load bundled dive centers from assets.
  Future<List<ExternalDiveCenter>> _loadBundledCenters() async {
    if (_bundledCenters != null) return _bundledCenters!;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/dive_centers.json',
      );
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final centersList = data['centers'] as List<dynamic>;

      _bundledCenters = centersList.map((item) {
        final center = item as Map<String, dynamic>;
        return ExternalDiveCenter(
          externalId: center['id'] as String,
          name: center['name'] as String,
          location: center['location'] as String?,
          latitude: _parseDouble(center['latitude']),
          longitude: _parseDouble(center['longitude']),
          country: center['country'] as String?,
          phone: center['phone'] as String?,
          email: center['email'] as String?,
          website: center['website'] as String?,
          affiliations: _parseAffiliations(center['affiliations']),
          type: center['type'] as String? ?? 'center',
          source: 'Bundled dive center database',
        );
      }).toList();

      _log.info('Loaded ${_bundledCenters!.length} bundled dive centers');
      return _bundledCenters!;
    } catch (e) {
      _log.warning('Failed to load bundled dive centers: $e');
      return [];
    }
  }

  /// Parse affiliations from string or list.
  List<String> _parseAffiliations(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    if (value is String) {
      return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  /// Search bundled dive centers by query.
  Future<DiveCenterSearchResult> _searchBundledCenters(String query) async {
    final centers = await _loadBundledCenters();
    if (centers.isEmpty) {
      return DiveCenterSearchResult.error('No dive centers available.');
    }

    final lowerQuery = query.toLowerCase().trim();
    final matchedCenters = centers.where((center) {
      final name = center.name.toLowerCase();
      final country = center.country?.toLowerCase() ?? '';
      final location = center.location?.toLowerCase() ?? '';
      final affiliations = center.affiliations.join(' ').toLowerCase();

      return name.contains(lowerQuery) ||
          country.contains(lowerQuery) ||
          location.contains(lowerQuery) ||
          affiliations.contains(lowerQuery) ||
          lowerQuery.contains(name.split(' ').first);
    }).toList();

    if (matchedCenters.isEmpty) {
      return const DiveCenterSearchResult(
        centers: [],
        errorMessage: 'No matching dive centers found in the database.',
      );
    }

    return DiveCenterSearchResult(
      centers: matchedCenters,
      totalResults: matchedCenters.length,
    );
  }

  /// Search bundled centers by proximity to coordinates.
  Future<DiveCenterSearchResult> _searchNearbyBundled({
    required double latitude,
    required double longitude,
    double radiusKm = 100,
  }) async {
    final centers = await _loadBundledCenters();
    if (centers.isEmpty) {
      return const DiveCenterSearchResult(centers: []);
    }

    final nearbyCenters = centers.where((center) {
      if (!center.hasCoordinates) return false;
      final distance = _haversineDistance(
        latitude,
        longitude,
        center.latitude!,
        center.longitude!,
      );
      return distance <= radiusKm;
    }).toList();

    // Sort by distance
    nearbyCenters.sort((a, b) {
      final distA = _haversineDistance(
        latitude,
        longitude,
        a.latitude!,
        a.longitude!,
      );
      final distB = _haversineDistance(
        latitude,
        longitude,
        b.latitude!,
        b.longitude!,
      );
      return distA.compareTo(distB);
    });

    return DiveCenterSearchResult(
      centers: nearbyCenters,
      totalResults: nearbyCenters.length,
    );
  }

  /// Calculate distance between two points using Haversine formula.
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
