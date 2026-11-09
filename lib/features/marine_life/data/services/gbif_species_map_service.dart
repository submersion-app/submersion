import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:submersion/features/reef/data/services/reef_request_timeout.dart';
import 'package:submersion/features/reef/domain/services/species_catalog_matcher.dart';

/// GBIF lookups behind the species map's public layer (issue #4358).
///
/// The map only calls this while the diver has the public layer on; the
/// service itself never prefetches. Every map request carries the same
/// licence filter as the site page's nearby species (CC0 1.0 and CC BY 4.0
/// only): the app does not ship CC BY-NC records.
class GbifSpeciesMapService {
  static const String _host = 'api.gbif.org';
  static const String _matchPath = '/v1/species/match';
  static const String _userAgent = 'Submersion/1.0 (https://submersion.app)';

  final http.Client _client;
  final SpeciesCatalogMatcher? _matcher;
  final Duration _timeout;

  /// Answers per species id, a confident "GBIF does not know it" included.
  /// Failures are not stored, so the next look tries again.
  final Map<String, int?> _keys = {};

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
  /// to show: no confident species-rank match, no scientific name, or GBIF
  /// could not be reached.
  ///
  /// A built-in species uses the key bundled with the app and sends nothing.
  Future<int?> resolveTaxonKey({
    required String speciesId,
    String? scientificName,
  }) async {
    if (_keys.containsKey(speciesId)) return _keys[speciesId];

    final matcher = _matcher ?? await SpeciesCatalogMatcher.load();
    final bundled = matcher.gbifKeyFor(speciesId);
    if (bundled != null) return _keys[speciesId] = bundled;

    final name = scientificName?.trim() ?? '';
    if (name.isEmpty) return null;

    final uri = Uri.https(_host, _matchPath, {
      'name': name,
      'strict': 'true',
      'rank': 'SPECIES',
    });
    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(_timeout);
      if (response.statusCode != 200) {
        developer.log(
          'GBIF species match HTTP ${response.statusCode}',
          name: 'GbifSpeciesMapService',
        );
        return null;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return _keys[speciesId] = _acceptedKey(body);
    } on TimeoutException {
      return null;
    } catch (e) {
      developer.log(
        'GBIF species match failed: $e',
        name: 'GbifSpeciesMapService',
      );
      return null;
    }
  }

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
