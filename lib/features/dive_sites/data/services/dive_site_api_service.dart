import 'dart:convert';

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
    return DiveSiteSearchResult(
      sites: [],
      errorMessage: message,
    );
  }

  bool get isSuccess => errorMessage == null;
}

/// Service for searching and fetching dive sites from external APIs.
class DiveSiteApiService {
  static final _log = LoggerService.forClass(DiveSiteApiService);

  /// RapidAPI key for World Scuba Diving Sites API.
  /// Users should set this via environment variable or settings.
  String? rapidApiKey;

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
        _log.warning('RapidAPI search failed, falling back to open data: $e');
      }
    }

    // Fall back to open data sources
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

    // For now, return empty for nearby without API
    return const DiveSiteSearchResult(sites: []);
  }

  /// Search for dive sites by country.
  Future<DiveSiteSearchResult> searchByCountry(String country) async {
    if (rapidApiKey != null && rapidApiKey!.isNotEmpty) {
      try {
        return await _searchByCountryViaRapidApi(country);
      } catch (e) {
        _log.warning('RapidAPI country search failed: $e');
      }
    }

    return _searchViaOpenData(country);
  }

  /// Search using RapidAPI's World Scuba Diving Sites API.
  Future<DiveSiteSearchResult> _searchViaRapidApi(String query) async {
    final uri = Uri.parse(
      'https://world-scuba-diving-sites-api.p.rapidapi.com/api/divesite',
    ).replace(queryParameters: {'country': query});

    final response = await http.get(
      uri,
      headers: {
        'X-RapidAPI-Key': rapidApiKey!,
        'X-RapidAPI-Host': 'world-scuba-diving-sites-api.p.rapidapi.com',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('API returned ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final sites = _parseRapidApiResponse(data);

    return DiveSiteSearchResult(
      sites: sites,
      totalResults: sites.length,
    );
  }

  Future<DiveSiteSearchResult> _searchNearbyViaRapidApi({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    // The World Scuba Diving Sites API doesn't support coordinate search
    // We'd need to fetch all and filter client-side, which isn't practical
    return const DiveSiteSearchResult(sites: []);
  }

  Future<DiveSiteSearchResult> _searchByCountryViaRapidApi(
    String country,
  ) async {
    final uri = Uri.parse(
      'https://world-scuba-diving-sites-api.p.rapidapi.com/api/divesite',
    ).replace(queryParameters: {'country': country});

    final response = await http.get(
      uri,
      headers: {
        'X-RapidAPI-Key': rapidApiKey!,
        'X-RapidAPI-Host': 'world-scuba-diving-sites-api.p.rapidapi.com',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('API returned ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final sites = _parseRapidApiResponse(data);

    return DiveSiteSearchResult(
      sites: sites,
      totalResults: sites.length,
    );
  }

  List<ExternalDiveSite> _parseRapidApiResponse(Map<String, dynamic> data) {
    final sites = <ExternalDiveSite>[];

    final dataList = data['data'] as List<dynamic>?;
    if (dataList == null) return sites;

    for (final item in dataList) {
      if (item is! Map<String, dynamic>) continue;

      try {
        sites.add(ExternalDiveSite(
          externalId: '${item['id'] ?? sites.length}',
          name: item['site_name'] as String? ?? 'Unknown',
          latitude: _parseDouble(item['latitude']),
          longitude: _parseDouble(item['longitude']),
          country: item['country'] as String?,
          region: item['region'] as String?,
          ocean: item['ocean'] as String?,
          source: 'World Scuba Diving Sites API',
        ),);
      } catch (e) {
        _log.warning('Failed to parse dive site: $e');
      }
    }

    return sites;
  }

  /// Search using open data sources (no API key required).
  Future<DiveSiteSearchResult> _searchViaOpenData(String query) async {
    // Use a curated list of popular dive sites as fallback
    // This provides basic functionality without requiring API keys
    final sites = _getPopularDiveSites()
        .where(
          (site) =>
              site.name.toLowerCase().contains(query.toLowerCase()) ||
              (site.country?.toLowerCase().contains(query.toLowerCase()) ??
                  false) ||
              (site.region?.toLowerCase().contains(query.toLowerCase()) ??
                  false),
        )
        .toList();

    return DiveSiteSearchResult(
      sites: sites,
      totalResults: sites.length,
    );
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Returns a curated list of popular dive sites worldwide.
  /// This serves as fallback data when no API key is configured.
  List<ExternalDiveSite> _getPopularDiveSites() {
    return const [
      // Caribbean
      ExternalDiveSite(
        externalId: 'pop_1',
        name: 'Blue Hole',
        description:
            'Famous underwater sinkhole, one of the top dive sites in the world.',
        latitude: 17.3156,
        longitude: -87.5347,
        maxDepth: 124,
        country: 'Belize',
        region: 'Caribbean',
        features: ['Wall dive', 'Stalactites', 'Sharks'],
        source: 'Popular Dive Sites',
      ),
      ExternalDiveSite(
        externalId: 'pop_2',
        name: 'USS Kittiwake',
        description:
            'Purposely sunk submarine rescue vessel, excellent wreck dive.',
        latitude: 19.3603,
        longitude: -81.4006,
        maxDepth: 19,
        country: 'Cayman Islands',
        region: 'Caribbean',
        features: ['Wreck', 'Penetration', 'Marine life'],
        source: 'Popular Dive Sites',
      ),

      // Red Sea
      ExternalDiveSite(
        externalId: 'pop_3',
        name: 'SS Thistlegorm',
        description:
            'WWII British cargo ship, one of the most famous wrecks in the world.',
        latitude: 27.8132,
        longitude: 33.9213,
        maxDepth: 30,
        country: 'Egypt',
        region: 'Red Sea',
        features: ['Wreck', 'WWII', 'Motorcycles', 'Trucks'],
        source: 'Popular Dive Sites',
      ),
      ExternalDiveSite(
        externalId: 'pop_4',
        name: 'Ras Mohammed',
        description: 'National park with stunning coral walls and marine life.',
        latitude: 27.7275,
        longitude: 34.2561,
        maxDepth: 40,
        country: 'Egypt',
        region: 'Red Sea',
        features: ['Coral walls', 'Pelagics', 'Sharks'],
        source: 'Popular Dive Sites',
      ),

      // Southeast Asia
      ExternalDiveSite(
        externalId: 'pop_5',
        name: 'Richelieu Rock',
        description:
            'Underwater pinnacle known for whale shark and manta encounters.',
        latitude: 9.3647,
        longitude: 98.0253,
        maxDepth: 35,
        country: 'Thailand',
        region: 'Andaman Sea',
        features: ['Pinnacle', 'Whale sharks', 'Mantas', 'Macro'],
        source: 'Popular Dive Sites',
      ),
      ExternalDiveSite(
        externalId: 'pop_6',
        name: 'Tubbataha Reef',
        description: 'UNESCO World Heritage Site with pristine coral reefs.',
        latitude: 8.9167,
        longitude: 119.8333,
        maxDepth: 40,
        country: 'Philippines',
        region: 'Sulu Sea',
        features: ['Coral reef', 'Sharks', 'Mantas', 'UNESCO'],
        source: 'Popular Dive Sites',
      ),
      ExternalDiveSite(
        externalId: 'pop_7',
        name: 'Sipadan Island',
        description:
            'Famous for massive schools of barracuda and sea turtles.',
        latitude: 4.1147,
        longitude: 118.6289,
        maxDepth: 40,
        country: 'Malaysia',
        region: 'Celebes Sea',
        features: ['Barracuda', 'Turtles', 'Wall dive', 'Sharks'],
        source: 'Popular Dive Sites',
      ),

      // Pacific
      ExternalDiveSite(
        externalId: 'pop_8',
        name: 'Blue Corner',
        description: 'High-current dive with incredible shark action.',
        latitude: 7.1361,
        longitude: 134.2164,
        maxDepth: 30,
        country: 'Palau',
        region: 'Pacific',
        features: ['Sharks', 'Current', 'Pelagics'],
        source: 'Popular Dive Sites',
      ),
      ExternalDiveSite(
        externalId: 'pop_9',
        name: 'Great Barrier Reef - Cod Hole',
        description: 'Famous for friendly potato cod interactions.',
        latitude: -14.6769,
        longitude: 145.6281,
        maxDepth: 25,
        country: 'Australia',
        region: 'Coral Sea',
        features: ['Potato cod', 'Coral reef', 'Marine life'],
        source: 'Popular Dive Sites',
      ),

      // Maldives
      ExternalDiveSite(
        externalId: 'pop_10',
        name: 'Manta Point',
        description: 'Cleaning station with regular manta ray encounters.',
        latitude: 3.9533,
        longitude: 73.4719,
        maxDepth: 25,
        country: 'Maldives',
        region: 'Indian Ocean',
        features: ['Mantas', 'Cleaning station', 'Coral'],
        source: 'Popular Dive Sites',
      ),

      // Galapagos
      ExternalDiveSite(
        externalId: 'pop_11',
        name: 'Darwin\'s Arch',
        description:
            'World-famous site for hammerhead sharks and whale sharks.',
        latitude: 1.6781,
        longitude: -91.9886,
        maxDepth: 30,
        country: 'Ecuador',
        region: 'Galapagos',
        features: ['Hammerheads', 'Whale sharks', 'Current'],
        source: 'Popular Dive Sites',
      ),
      ExternalDiveSite(
        externalId: 'pop_12',
        name: 'Gordon Rocks',
        description: 'Challenging dive with hammerhead shark schools.',
        latitude: -0.7917,
        longitude: -90.4917,
        maxDepth: 32,
        country: 'Ecuador',
        region: 'Galapagos',
        features: ['Hammerheads', 'Sea lions', 'Current'],
        source: 'Popular Dive Sites',
      ),

      // Indonesia
      ExternalDiveSite(
        externalId: 'pop_13',
        name: 'Manta Sandy',
        description: 'Reliable manta cleaning station in Raja Ampat.',
        latitude: -0.5461,
        longitude: 130.6489,
        maxDepth: 18,
        country: 'Indonesia',
        region: 'Raja Ampat',
        features: ['Mantas', 'Cleaning station', 'Coral'],
        source: 'Popular Dive Sites',
      ),
      ExternalDiveSite(
        externalId: 'pop_14',
        name: 'Liberty Wreck',
        description: 'WWII cargo ship wreck, excellent for all levels.',
        latitude: -8.2733,
        longitude: 115.5956,
        maxDepth: 30,
        country: 'Indonesia',
        region: 'Bali',
        features: ['Wreck', 'Shore dive', 'Marine life'],
        source: 'Popular Dive Sites',
      ),

      // Mexico
      ExternalDiveSite(
        externalId: 'pop_15',
        name: 'Cenote Dos Ojos',
        description: 'Famous freshwater cenote with crystal clear visibility.',
        latitude: 20.3269,
        longitude: -87.3917,
        maxDepth: 10,
        country: 'Mexico',
        region: 'Yucatan',
        features: ['Cenote', 'Cave', 'Freshwater', 'Stalactites'],
        source: 'Popular Dive Sites',
      ),
      ExternalDiveSite(
        externalId: 'pop_16',
        name: 'Socorro - El Boiler',
        description: 'Remote island with giant manta and dolphin encounters.',
        latitude: 18.7867,
        longitude: -110.9617,
        maxDepth: 25,
        country: 'Mexico',
        region: 'Pacific',
        features: ['Giant mantas', 'Dolphins', 'Sharks'],
        source: 'Popular Dive Sites',
      ),

      // Mediterranean
      ExternalDiveSite(
        externalId: 'pop_17',
        name: 'MS Zenobia',
        description: 'One of the top 10 wreck dives in the world.',
        latitude: 34.9161,
        longitude: 33.6469,
        maxDepth: 42,
        country: 'Cyprus',
        region: 'Mediterranean',
        features: ['Wreck', 'Trucks', 'Penetration'],
        source: 'Popular Dive Sites',
      ),
      ExternalDiveSite(
        externalId: 'pop_18',
        name: 'El Toro',
        description: 'Marine reserve with abundant fish life.',
        latitude: 39.4550,
        longitude: 2.4736,
        maxDepth: 25,
        country: 'Spain',
        region: 'Mallorca',
        features: ['Marine reserve', 'Groupers', 'Barracuda'],
        source: 'Popular Dive Sites',
      ),

      // Florida
      ExternalDiveSite(
        externalId: 'pop_19',
        name: 'Molasses Reef',
        description: 'Popular reef in the Florida Keys marine sanctuary.',
        latitude: 25.0117,
        longitude: -80.3753,
        maxDepth: 12,
        country: 'United States',
        region: 'Florida Keys',
        features: ['Coral reef', 'Tropical fish', 'Easy dive'],
        source: 'Popular Dive Sites',
      ),
      ExternalDiveSite(
        externalId: 'pop_20',
        name: 'Blue Heron Bridge',
        description: 'World-class muck diving under a bridge.',
        latitude: 26.7831,
        longitude: -80.0450,
        maxDepth: 6,
        country: 'United States',
        region: 'Florida',
        features: ['Muck diving', 'Macro', 'Seahorses', 'Shore dive'],
        source: 'Popular Dive Sites',
      ),

      // Hawaii
      ExternalDiveSite(
        externalId: 'pop_21',
        name: 'Manta Ray Night Dive',
        description: 'Night dive with manta rays attracted by lights.',
        latitude: 19.7286,
        longitude: -156.0456,
        maxDepth: 10,
        country: 'United States',
        region: 'Hawaii',
        features: ['Mantas', 'Night dive', 'Easy dive'],
        source: 'Popular Dive Sites',
      ),

      // Costa Rica
      ExternalDiveSite(
        externalId: 'pop_22',
        name: 'Cocos Island - Bajo Alcyone',
        description: 'Famous seamount with schooling hammerheads.',
        latitude: 5.5317,
        longitude: -87.0433,
        maxDepth: 30,
        country: 'Costa Rica',
        region: 'Pacific',
        features: ['Hammerheads', 'Seamount', 'Pelagics'],
        source: 'Popular Dive Sites',
      ),

      // South Africa
      ExternalDiveSite(
        externalId: 'pop_23',
        name: 'Aliwal Shoal',
        description: 'Shark diving destination with ragged-tooth sharks.',
        latitude: -30.2633,
        longitude: 30.8167,
        maxDepth: 27,
        country: 'South Africa',
        region: 'KwaZulu-Natal',
        features: ['Sharks', 'Ragged-tooth', 'Wrecks'],
        source: 'Popular Dive Sites',
      ),

      // Japan
      ExternalDiveSite(
        externalId: 'pop_24',
        name: 'Yonaguni Monument',
        description: 'Mysterious underwater rock formation.',
        latitude: 24.4353,
        longitude: 123.0106,
        maxDepth: 25,
        country: 'Japan',
        region: 'Okinawa',
        features: ['Rock formation', 'Hammerheads', 'Mystery'],
        source: 'Popular Dive Sites',
      ),

      // Fiji
      ExternalDiveSite(
        externalId: 'pop_25',
        name: 'Great White Wall',
        description: 'Soft coral wall covered in white coral.',
        latitude: -16.8500,
        longitude: -179.8667,
        maxDepth: 30,
        country: 'Fiji',
        region: 'Somosomo Strait',
        features: ['Soft coral', 'Wall dive', 'Current'],
        source: 'Popular Dive Sites',
      ),
    ];
  }
}
