import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/services/species_catalog_matcher.dart';

/// Fetches species recorded near a dive site from GBIF.
///
/// The licence filter is mandatory: roughly a quarter of occurrence records
/// near a typical reef are CC BY-NC, and omitting the filter would ship a
/// licensing violation. The order whitelist is mandatory too: without it a
/// 5 km radius around a coastal site is dominated by birds, which would eat
/// every facet slot.
class NearbySpeciesService {
  final http.Client _client;
  final SpeciesCatalogMatcher? _matcher;

  static const String _host = 'api.gbif.org';
  static const String _searchPath = '/v1/occurrence/search';
  static const String _speciesPath = '/v1/species';
  static const String _userAgent = 'Submersion/1.0 (https://submersion.app)';

  /// A 5 km radius measurably reduces land bleed compared with 10 km.
  static const String _radius = '5km';

  /// GBIF caps facetLimit at 300 regardless of what is requested.
  static const String _facetLimit = '300';

  /// Live name lookups are capped so a cold cache cannot stall the UI.
  static const int maxUnmatched = 25;

  NearbySpeciesService({http.Client? client, SpeciesCatalogMatcher? matcher})
    : _client = client ?? http.Client(),
      _matcher = matcher;

  Future<ReefPart<NearbySpecies>> fetch(GeoPoint point) async {
    try {
      final matcher = _matcher ?? await SpeciesCatalogMatcher.load();

      final uri = Uri.https(_host, _searchPath, {
        'geoDistance':
            '${point.latitude.toStringAsFixed(3)},'
            '${point.longitude.toStringAsFixed(3)},$_radius',
        'license': ['CC0_1_0', 'CC_BY_4_0'],
        'occurrenceStatus': 'PRESENT',
        'hasGeospatialIssue': 'false',
        'taxonKey': matcher.orderKeys.map((k) => k.toString()).toList(),
        'facet': 'speciesKey',
        'facetLimit': _facetLimit,
        'limit': '0',
      });

      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode != 200) {
        developer.log(
          'Nearby species HTTP ${response.statusCode}',
          name: 'NearbySpeciesService',
        );
        return const ReefPart.unavailable();
      }

      final counts = _facetCounts(response.body);
      if (counts.isEmpty) return const ReefPart.empty();

      final matched = <MatchedNearbySpecies>[];
      final unmatchedKeys = <int>[];
      for (final entry in counts) {
        final localId = matcher.localIdFor(entry.key);
        if (localId != null) {
          matched.add(
            MatchedNearbySpecies(
              speciesId: localId,
              occurrenceCount: entry.count,
            ),
          );
        } else if (unmatchedKeys.length < maxUnmatched) {
          unmatchedKeys.add(entry.key);
        }
      }

      // Resolved concurrently. Sequentially these are up to 25 round trips at
      // roughly 0.4s each, which would stall the site view for ten seconds.
      // The cap keeps the burst small enough to stay polite.
      final resolved = await Future.wait(unmatchedKeys.map(_scientificName));
      final unmatchedNames = resolved.whereType<String>().toList();

      final result = NearbySpecies(
        matched: matched,
        unmatchedNames: unmatchedNames,
      );
      if (result.isEmpty) return const ReefPart.empty();
      return ReefPart.ok(result);
    } catch (e) {
      developer.log(
        'Nearby species fetch failed: $e',
        name: 'NearbySpeciesService',
      );
      return const ReefPart.unavailable();
    }
  }

  Map<String, String> get _headers => const {'User-Agent': _userAgent};

  List<_FacetCount> _facetCounts(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];
    final facets = decoded['facets'];
    if (facets is! List || facets.isEmpty) return const [];

    final first = facets.first;
    if (first is! Map<String, dynamic>) return const [];
    final counts = first['counts'];
    if (counts is! List) return const [];

    return counts
        .whereType<Map<String, dynamic>>()
        .map((c) {
          final key = int.tryParse('${c['name']}');
          if (key == null) return null;
          return _FacetCount(key, (c['count'] as num?)?.toInt() ?? 0);
        })
        .whereType<_FacetCount>()
        .toList(growable: false);
  }

  Future<String?> _scientificName(int key) async {
    try {
      final response = await _client.get(
        Uri.https(_host, '$_speciesPath/$key'),
        headers: _headers,
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final name = decoded['scientificName'];
      return name is String && name.isNotEmpty ? name : null;
    } catch (_) {
      return null;
    }
  }
}

class _FacetCount {
  final int key;
  final int count;
  const _FacetCount(this.key, this.count);
}
