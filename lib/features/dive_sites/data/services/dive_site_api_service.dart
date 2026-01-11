import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../../../../core/services/logger_service.dart';
import '../../domain/entities/dive_site.dart';

/// A dive site result from the bundled database.
class ExternalDiveSite {
  final String externalId;
  final String name;
  final String? description;
  final double? latitude;
  final double? longitude;
  final double? maxDepth;
  final String? country;
  final String? region;
  final String? ocean;
  final List<String> features;
  final String source;

  const ExternalDiveSite({
    required this.externalId,
    required this.name,
    this.description,
    this.latitude,
    this.longitude,
    this.maxDepth,
    this.country,
    this.region,
    this.ocean,
    this.features = const [],
    required this.source,
  });

  /// Whether this site has valid coordinates.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Convert to a DiveSite entity for import.
  DiveSite toDiveSite({String? diverId}) {
    return DiveSite(
      id: '',
      diverId: diverId,
      name: name,
      description: _buildDescription(),
      location: hasCoordinates ? GeoPoint(latitude!, longitude!) : null,
      maxDepth: maxDepth,
      country: country,
      region: region ?? ocean,
      notes: 'Imported from $source',
    );
  }

  String _buildDescription() {
    final parts = <String>[];
    if (description != null && description!.isNotEmpty) {
      parts.add(description!);
    }
    if (features.isNotEmpty) {
      parts.add('Features: ${features.join(", ")}');
    }
    return parts.join('\n\n');
  }
}

/// Search result from the dive site service.
class DiveSiteSearchResult {
  final List<ExternalDiveSite> sites;
  final int totalResults;
  final bool hasMore;
  final String? errorMessage;

  const DiveSiteSearchResult({
    required this.sites,
    this.totalResults = 0,
    this.hasMore = false,
    this.errorMessage,
  });

  factory DiveSiteSearchResult.error(String message) {
    return DiveSiteSearchResult(sites: [], errorMessage: message);
  }

  bool get isSuccess => errorMessage == null;
}

/// Service for searching dive sites from the bundled database.
class DiveSiteApiService {
  static final _log = LoggerService.forClass(DiveSiteApiService);

  /// Cached bundled dive sites to avoid reloading.
  List<ExternalDiveSite>? _bundledSites;

  /// Search for dive sites by query string.
  Future<DiveSiteSearchResult> searchSites(String query) async {
    if (query.trim().isEmpty) {
      return const DiveSiteSearchResult(sites: []);
    }
    return _searchBundledSites(query);
  }

  /// Search for dive sites near coordinates.
  Future<DiveSiteSearchResult> searchNearby({
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

  /// Search for dive sites by country.
  Future<DiveSiteSearchResult> searchByCountry(String country) async {
    return _searchBundledSites(country);
  }

  /// Load bundled dive sites from assets.
  Future<List<ExternalDiveSite>> _loadBundledSites() async {
    if (_bundledSites != null) return _bundledSites!;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/dive_sites.json',
      );
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final sitesList = data['sites'] as List<dynamic>;

      _bundledSites = sitesList.map((item) {
        final site = item as Map<String, dynamic>;
        return ExternalDiveSite(
          externalId: site['id'] as String,
          name: site['name'] as String,
          description: site['description'] as String?,
          latitude: _parseDouble(site['latitude']),
          longitude: _parseDouble(site['longitude']),
          maxDepth: _parseDouble(site['max_depth']),
          country: site['country'] as String?,
          region: site['region'] as String?,
          ocean: site['ocean'] as String?,
          source: 'Bundled dive site database',
        );
      }).toList();

      _log.info('Loaded ${_bundledSites!.length} bundled dive sites');
      return _bundledSites!;
    } catch (e) {
      _log.warning('Failed to load bundled dive sites: $e');
      return [];
    }
  }

  /// Search bundled dive sites by query.
  Future<DiveSiteSearchResult> _searchBundledSites(String query) async {
    final sites = await _loadBundledSites();
    if (sites.isEmpty) {
      return DiveSiteSearchResult.error('No dive sites available.');
    }

    final lowerQuery = query.toLowerCase().trim();
    final matchedSites = sites.where((site) {
      final name = site.name.toLowerCase();
      final country = site.country?.toLowerCase() ?? '';
      final region = site.region?.toLowerCase() ?? '';
      final ocean = site.ocean?.toLowerCase() ?? '';
      final description = site.description?.toLowerCase() ?? '';

      return name.contains(lowerQuery) ||
          country.contains(lowerQuery) ||
          region.contains(lowerQuery) ||
          ocean.contains(lowerQuery) ||
          description.contains(lowerQuery) ||
          lowerQuery.contains(name.split(' ').first);
    }).toList();

    if (matchedSites.isEmpty) {
      return const DiveSiteSearchResult(
        sites: [],
        errorMessage: 'No matching sites found in the database.',
      );
    }

    return DiveSiteSearchResult(
      sites: matchedSites,
      totalResults: matchedSites.length,
    );
  }

  /// Search bundled sites by proximity to coordinates.
  Future<DiveSiteSearchResult> _searchNearbyBundled({
    required double latitude,
    required double longitude,
    double radiusKm = 100,
  }) async {
    final sites = await _loadBundledSites();
    if (sites.isEmpty) {
      return const DiveSiteSearchResult(sites: []);
    }

    final nearbySites = sites.where((site) {
      if (!site.hasCoordinates) return false;
      final distance = _haversineDistance(
        latitude,
        longitude,
        site.latitude!,
        site.longitude!,
      );
      return distance <= radiusKm;
    }).toList();

    // Sort by distance
    nearbySites.sort((a, b) {
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

    return DiveSiteSearchResult(
      sites: nearbySites,
      totalResults: nearbySites.length,
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
