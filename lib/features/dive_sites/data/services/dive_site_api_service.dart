import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../../../core/services/logger_service.dart';
import '../../domain/entities/dive_site.dart';

/// A dive site result from an external API.
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

/// Search result from the dive site API.
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

/// Service for searching and fetching dive sites from external APIs.
class DiveSiteApiService {
  static final _log = LoggerService.forClass(DiveSiteApiService);

  /// RapidAPI key for World Scuba Diving Sites API.
  /// Users should set this via environment variable or settings.
  String? rapidApiKey;

  /// Test if the RapidAPI key is valid by making a simple API call.
  /// Returns a tuple of (isValid, errorMessage).
  Future<(bool, String?)> testApiKeyWithDetails(String key) async {
    try {
      // Use GPS bounding box search - testing with a small area in the UK
      final uri =
          Uri.parse(
            'https://world-scuba-diving-sites-api.p.rapidapi.com/divesites/gps',
          ).replace(
            queryParameters: {
              'southWestLat': '50.0',
              'northEastLat': '51.0',
              'southWestLng': '-1.0',
              'northEastLng': '0.0',
            },
          );

      final response = await http.get(
        uri,
        headers: {
          'x-rapidapi-key': key,
          'x-rapidapi-host': 'world-scuba-diving-sites-api.p.rapidapi.com',
        },
      );

      _log.info('RapidAPI test response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return (true, null);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return (false, 'Invalid API key or not subscribed to this API');
      } else if (response.statusCode == 429) {
        return (false, 'Rate limit exceeded - try again later');
      } else {
        return (false, 'API returned status ${response.statusCode}');
      }
    } catch (e) {
      _log.warning('RapidAPI test failed: $e');
      return (false, 'Connection error: $e');
    }
  }

  /// Test if the RapidAPI key is valid by making a simple API call.
  /// Returns true if the key works, false otherwise.
  Future<bool> testApiKey(String key) async {
    final (isValid, _) = await testApiKeyWithDetails(key);
    return isValid;
  }

  /// Search for dive sites by query string.
  Future<DiveSiteSearchResult> searchSites(String query) async {
    if (query.trim().isEmpty) {
      return const DiveSiteSearchResult(sites: []);
    }

    // Try RapidAPI if key is configured
    if (rapidApiKey != null && rapidApiKey!.isNotEmpty) {
      try {
        return await _searchViaRapidApi(query);
      } catch (e) {
        _log.warning('RapidAPI search failed: $e');
        // Return error instead of silently falling back
        return DiveSiteSearchResult.error(
          'API search failed. Check your RapidAPI key in Settings > API Keys.',
        );
      }
    }

    // Fall back to open data sources (only when no API key configured)
    return _searchViaOpenData(query);
  }

  /// Search for dive sites near coordinates.
  Future<DiveSiteSearchResult> searchNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
  }) async {
    // Try RapidAPI if key is configured
    if (rapidApiKey != null && rapidApiKey!.isNotEmpty) {
      try {
        return await _searchNearbyViaRapidApi(
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
        );
      } catch (e) {
        _log.warning('RapidAPI nearby search failed: $e');
      }
    }

    // Fall back to bundled sites
    return _searchNearbyViaBundled(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
  }

  /// Search for dive sites by country.
  Future<DiveSiteSearchResult> searchByCountry(String country) async {
    if (rapidApiKey != null && rapidApiKey!.isNotEmpty) {
      try {
        return await _searchByCountryViaRapidApi(country);
      } catch (e) {
        _log.warning('RapidAPI country search failed: $e');
        return DiveSiteSearchResult.error(
          'API search failed. Check your RapidAPI key in Settings > API Keys.',
        );
      }
    }

    return _searchViaOpenData(country);
  }

  /// GPS bounding boxes for common diving regions.
  static const Map<String, Map<String, double>> _regionBoundingBoxes = {
    // Caribbean
    'caribbean': {'swLat': 10.0, 'neLat': 27.0, 'swLng': -88.0, 'neLng': -59.0},
    'cayman': {'swLat': 19.2, 'neLat': 19.8, 'swLng': -81.5, 'neLng': -79.7},
    'bahamas': {'swLat': 20.9, 'neLat': 27.3, 'swLng': -80.5, 'neLng': -72.7},
    'belize': {'swLat': 15.8, 'neLat': 18.5, 'swLng': -89.2, 'neLng': -87.4},
    // Red Sea
    'red sea': {'swLat': 12.0, 'neLat': 30.0, 'swLng': 32.0, 'neLng': 44.0},
    'egypt': {'swLat': 22.0, 'neLat': 31.7, 'swLng': 24.7, 'neLng': 36.9},
    // Southeast Asia
    'thailand': {'swLat': 5.6, 'neLat': 20.5, 'swLng': 97.3, 'neLng': 105.6},
    'indonesia': {'swLat': -11.0, 'neLat': 6.0, 'swLng': 95.0, 'neLng': 141.0},
    'philippines': {
      'swLat': 4.5,
      'neLat': 21.2,
      'swLng': 116.9,
      'neLng': 126.6,
    },
    'malaysia': {'swLat': 0.8, 'neLat': 7.4, 'swLng': 99.6, 'neLng': 119.3},
    'raja ampat': {'swLat': -4.5, 'neLat': 0.5, 'swLng': 129.0, 'neLng': 132.0},
    'bali': {'swLat': -8.9, 'neLat': -8.0, 'swLng': 114.4, 'neLng': 115.7},
    // Pacific
    'maldives': {'swLat': -0.7, 'neLat': 7.1, 'swLng': 72.6, 'neLng': 73.8},
    'fiji': {'swLat': -21.0, 'neLat': -12.5, 'swLng': 177.0, 'neLng': -179.0},
    'palau': {'swLat': 2.8, 'neLat': 8.1, 'swLng': 131.1, 'neLng': 134.7},
    'australia': {
      'swLat': -44.0,
      'neLat': -10.0,
      'swLng': 113.0,
      'neLng': 154.0,
    },
    'great barrier reef': {
      'swLat': -24.5,
      'neLat': -10.7,
      'swLng': 142.5,
      'neLng': 154.0,
    },
    // Americas
    'mexico': {'swLat': 14.5, 'neLat': 32.7, 'swLng': -118.4, 'neLng': -86.7},
    'florida': {'swLat': 24.4, 'neLat': 31.0, 'swLng': -87.6, 'neLng': -80.0},
    'hawaii': {'swLat': 18.9, 'neLat': 22.2, 'swLng': -160.2, 'neLng': -154.8},
    'galapagos': {'swLat': -1.5, 'neLat': 0.5, 'swLng': -92.0, 'neLng': -89.0},
    'costa rica': {'swLat': 8.0, 'neLat': 11.2, 'swLng': -85.9, 'neLng': -82.6},
    // Europe/Mediterranean
    'mediterranean': {
      'swLat': 30.0,
      'neLat': 46.0,
      'swLng': -6.0,
      'neLng': 36.0,
    },
    'spain': {'swLat': 36.0, 'neLat': 43.8, 'swLng': -9.3, 'neLng': 3.3},
    'malta': {'swLat': 35.8, 'neLat': 36.1, 'swLng': 14.1, 'neLng': 14.6},
    'croatia': {'swLat': 42.4, 'neLat': 46.6, 'swLng': 13.5, 'neLng': 19.4},
    'uk': {'swLat': 49.9, 'neLat': 60.9, 'swLng': -8.6, 'neLng': 1.8},
    // Africa
    'south africa': {
      'swLat': -35.0,
      'neLat': -22.1,
      'swLng': 16.5,
      'neLng': 32.9,
    },
    // Japan
    'japan': {'swLat': 24.0, 'neLat': 45.5, 'swLng': 122.9, 'neLng': 145.8},
    'okinawa': {'swLat': 24.0, 'neLat': 27.9, 'swLng': 122.9, 'neLng': 131.3},
  };

  /// Search using RapidAPI's World Scuba Diving Sites API.
  /// First tries location-based text search, then falls back to GPS bounding box.
  Future<DiveSiteSearchResult> _searchViaRapidApi(String query) async {
    final lowerQuery = query.toLowerCase().trim();

    // First, try the location-based text search endpoint
    try {
      final result = await _searchByLocation(query);
      if (result.sites.isNotEmpty) {
        return result;
      }
    } catch (e) {
      _log.info('Location search failed, trying GPS bounding box: $e');
    }

    // Fall back to GPS bounding box search if text search returns empty
    Map<String, double>? boundingBox;
    String? matchedRegion;
    for (final entry in _regionBoundingBoxes.entries) {
      // Check for partial matches (at least 3 characters)
      if (lowerQuery.length >= 3) {
        if (entry.key.startsWith(lowerQuery) ||
            lowerQuery.startsWith(entry.key) ||
            entry.key.contains(lowerQuery) ||
            lowerQuery.contains(entry.key)) {
          boundingBox = entry.value;
          matchedRegion = entry.key;
          break;
        }
      } else if (lowerQuery == entry.key) {
        boundingBox = entry.value;
        matchedRegion = entry.key;
        break;
      }
    }

    if (boundingBox == null) {
      // No matching region found, search local database instead
      _log.info('No GPS bounding box found for "$query", using local search');
      return _searchViaOpenData(query);
    }

    final result = await _searchByBoundingBox(
      southWestLat: boundingBox['swLat']!,
      northEastLat: boundingBox['neLat']!,
      southWestLng: boundingBox['swLng']!,
      northEastLng: boundingBox['neLng']!,
    );

    // If query is more specific than the region name, filter results
    if (matchedRegion != null && lowerQuery != matchedRegion) {
      final filteredSites = result.sites.where((site) {
        final siteName = site.name.toLowerCase();
        final siteCountry = site.country?.toLowerCase() ?? '';
        final siteRegion = site.region?.toLowerCase() ?? '';
        return siteName.contains(lowerQuery) ||
            siteCountry.contains(lowerQuery) ||
            siteRegion.contains(lowerQuery) ||
            lowerQuery.contains(siteName.split(' ').first);
      }).toList();

      // If we have filtered results, return them; otherwise return all
      if (filteredSites.isNotEmpty) {
        return DiveSiteSearchResult(
          sites: filteredSites,
          totalResults: filteredSites.length,
        );
      }
    }

    return result;
  }

  /// Search by location name/region text query.
  Future<DiveSiteSearchResult> _searchByLocation(String location) async {
    final uri = Uri.parse(
      'https://world-scuba-diving-sites-api.p.rapidapi.com/divesites',
    ).replace(queryParameters: {'location': location});

    final response = await http.get(
      uri,
      headers: {
        'x-rapidapi-key': rapidApiKey!,
        'x-rapidapi-host': 'world-scuba-diving-sites-api.p.rapidapi.com',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final sites = _parseGpsApiResponse(data);
      return DiveSiteSearchResult(sites: sites, totalResults: sites.length);
    } else {
      throw Exception('Location search returned ${response.statusCode}');
    }
  }

  /// Search by GPS bounding box.
  Future<DiveSiteSearchResult> _searchByBoundingBox({
    required double southWestLat,
    required double northEastLat,
    required double southWestLng,
    required double northEastLng,
  }) async {
    final uri =
        Uri.parse(
          'https://world-scuba-diving-sites-api.p.rapidapi.com/divesites/gps',
        ).replace(
          queryParameters: {
            'southWestLat': southWestLat.toString(),
            'northEastLat': northEastLat.toString(),
            'southWestLng': southWestLng.toString(),
            'northEastLng': northEastLng.toString(),
          },
        );

    final response = await http.get(
      uri,
      headers: {
        'x-rapidapi-key': rapidApiKey!,
        'x-rapidapi-host': 'world-scuba-diving-sites-api.p.rapidapi.com',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final sites = _parseGpsApiResponse(data);
      return DiveSiteSearchResult(sites: sites, totalResults: sites.length);
    } else {
      throw Exception('API returned ${response.statusCode}');
    }
  }

  Future<DiveSiteSearchResult> _searchNearbyViaRapidApi({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    // Convert radius to bounding box (approximate)
    final latDelta = radiusKm / 111.0; // ~111km per degree latitude
    final lngDelta = radiusKm / (111.0 * cos(latitude * pi / 180));

    return _searchByBoundingBox(
      southWestLat: latitude - latDelta,
      northEastLat: latitude + latDelta,
      southWestLng: longitude - lngDelta,
      northEastLng: longitude + lngDelta,
    );
  }

  Future<DiveSiteSearchResult> _searchByCountryViaRapidApi(
    String country,
  ) async {
    // Use the same region-based search
    return _searchViaRapidApi(country);
  }

  /// Parse response from GPS-based API endpoint.
  List<ExternalDiveSite> _parseGpsApiResponse(dynamic data) {
    final sites = <ExternalDiveSite>[];

    // The GPS API returns a list directly
    final List<dynamic> dataList;
    if (data is List) {
      dataList = data;
    } else if (data is Map && data['data'] is List) {
      dataList = data['data'] as List;
    } else {
      _log.warning('Unexpected API response format: ${data.runtimeType}');
      return sites;
    }

    for (final item in dataList) {
      if (item is! Map<String, dynamic>) continue;

      try {
        sites.add(
          ExternalDiveSite(
            externalId: '${item['id'] ?? sites.length}',
            name:
                item['name'] as String? ??
                item['site_name'] as String? ??
                'Unknown',
            description: item['description'] as String?,
            latitude: _parseDouble(item['lat'] ?? item['latitude']),
            longitude: _parseDouble(item['lng'] ?? item['longitude']),
            maxDepth: _parseDouble(item['maxDepth'] ?? item['max_depth']),
            country: item['country'] as String?,
            region: item['region'] as String?,
            ocean: item['ocean'] as String?,
            source: 'World Scuba Diving Sites API',
          ),
        );
      } catch (e) {
        _log.warning('Failed to parse dive site: $e');
      }
    }

    return sites;
  }

  /// Cached bundled dive sites to avoid reloading.
  List<ExternalDiveSite>? _bundledSites;

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
  Future<DiveSiteSearchResult> _searchViaOpenData(String query) async {
    final sites = await _loadBundledSites();
    if (sites.isEmpty) {
      return DiveSiteSearchResult.error(
        'No bundled dive sites available. Configure a RapidAPI key for online search.',
      );
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
        errorMessage:
            'No matching sites in bundled database. Configure a RapidAPI key for online search.',
      );
    }

    return DiveSiteSearchResult(
      sites: matchedSites,
      totalResults: matchedSites.length,
    );
  }

  /// Search bundled sites by proximity to coordinates.
  Future<DiveSiteSearchResult> _searchNearbyViaBundled({
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
