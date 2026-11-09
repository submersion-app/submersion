import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:submersion/features/reef/data/services/reef_request_timeout.dart';
import 'package:submersion/features/reef/domain/services/species_catalog_matcher.dart';

/// GBIF could not answer (offline, timeout, an HTTP error). Distinct from a
/// confident "GBIF does not know this name", so the map can say "could not
/// load" instead of sending the diver off to fix a name that is fine.
class GbifUnavailableException implements Exception {
  final String message;

  const GbifUnavailableException(this.message);

  @override
  String toString() => 'GbifUnavailableException: $message';
}

/// GBIF lookups behind the species map's public layer (issue #4358).
///
/// The map only calls this while the diver has the public layer on; the
/// service itself never prefetches. Every map request carries the same
/// licence filter as the site page's nearby species (CC0 1.0 and CC BY 4.0
/// only): the app does not ship CC BY-NC records.
class GbifSpeciesMapService {
  static const String _host = 'api.gbif.org';
  static const String _matchPath = '/v1/species/match';

  /// Sent with every GBIF request the map makes, tiles included.
  static const String userAgent = 'Submersion/1.0 (https://submersion.app)';

  final http.Client _client;
  final SpeciesCatalogMatcher? _matcher;
  final Duration _timeout;

  /// Name-match answers per normalized scientific name, a confident "GBIF
  /// does not know it" included, so correcting a species' name asks again.
  /// Failures are not stored, so the next look tries again.
  final Map<String, int?> _byName = {};

  GbifSpeciesMapService({
    http.Client? client,
    SpeciesCatalogMatcher? matcher,
    Duration timeout = reefRequestTimeout,
  }) : _client = client ?? http.Client(),
       _matcher = matcher,
       _timeout = timeout;

  /// GBIF map tiles of one taxon's licence-filtered occurrence records.
  ///
  /// The `adhoc` endpoint is the one that honours `license`; the cheaper
  /// `density` endpoint ignores it, so it must not be used here.
  static String tileUrlTemplate(int taxonKey) =>
      'https://$_host/v2/map/occurrence/adhoc/{z}/{x}/{y}@1x.png?'
      'taxonKey=$taxonKey'
      '&license=CC0_1_0&license=CC_BY_4_0'
      '&occurrenceStatus=PRESENT&hasGeospatialIssue=false'
      '&style=orange.marker&bin=hex&hexPerTile=60';

  /// The GBIF species key for a catalog species, or null when there is none
  /// to show: no scientific name, or no confident species-rank match.
  ///
  /// A built-in species uses the key bundled with the app and sends nothing.
  /// Throws [GbifUnavailableException] when GBIF cannot be reached.
  Future<int?> resolveTaxonKey({
    required String speciesId,
    String? scientificName,
  }) async {
    final matcher = _matcher ?? await SpeciesCatalogMatcher.load();
    final bundled = matcher.gbifKeyFor(speciesId);
    if (bundled != null) return bundled;

    final name = scientificName?.trim() ?? '';
    if (name.isEmpty) return null;
    final cacheKey = name.toLowerCase();
    if (_byName.containsKey(cacheKey)) return _byName[cacheKey];

    final uri = Uri.https(_host, _matchPath, {
      'name': name,
      'strict': 'true',
      'rank': 'SPECIES',
    });
    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': userAgent})
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw GbifUnavailableException('HTTP ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return _byName[cacheKey] = _acceptedKey(body);
    } on GbifUnavailableException catch (e) {
      developer.log('$e', name: 'GbifSpeciesMapService');
      rethrow;
    } on TimeoutException {
      throw const GbifUnavailableException('timed out');
    } catch (e) {
      developer.log(
        'GBIF species match failed: $e',
        name: 'GbifSpeciesMapService',
      );
      throw GbifUnavailableException('$e');
    }
  }

  /// Releases the HTTP client. The provider calls it on dispose.
  void close() => _client.close();

  /// An exact species-rank match only. A fuzzy or higher-rank answer would
  /// draw some other animal's records under this species' name.
  static int? _acceptedKey(Map<String, dynamic> body) {
    if (body['rank'] != 'SPECIES' || body['matchType'] != 'EXACT') {
      return null;
    }
    final accepted = body['acceptedUsageKey'] ?? body['usageKey'];
    return accepted is num ? accepted.toInt() : null;
  }
}
