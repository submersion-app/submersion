import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/features/marine_life/data/services/inaturalist_parsers.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/domain/services/species_category_mapper.dart';

/// iNaturalist's public taxa API. Free to read, no key.
///
/// Explicit lookups only: callers send a request when the diver asks for
/// one, never per keystroke. Results are cached for the session so a
/// repeated query costs nothing.
class INaturalistSpeciesLookupService implements SpeciesLookupService {
  static const String _host = 'api.inaturalist.org';
  static const String _autocompletePath = '/v1/taxa/autocomplete';
  static const String _taxonPath = '/v1/taxa';
  static const String _userAgent = 'Submersion/1.0 (https://submersion.app)';

  final http.Client _client;
  final Duration _timeout;
  final Map<String, List<SpeciesLookupHit>> _searchCache = {};
  final Map<String, SpeciesLookupResult> _resolveCache = {};

  INaturalistSpeciesLookupService({
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _timeout = timeout;

  @override
  Future<List<SpeciesLookupHit>> search(
    String query, {
    required String locale,
  }) async {
    final term = query.trim();
    // One normalized code for both the cache key and the request, or a
    // caller passing 'DE' would read 'de''s cached answer while asking
    // iNaturalist for a different localization.
    final code = locale.toLowerCase();
    final key = '$code|${term.toLowerCase()}';
    final cached = _searchCache[key];
    if (cached != null) return cached;

    final uri = Uri.https(_host, _autocompletePath, {
      'q': term,
      'locale': code,
      'per_page': '10',
      'is_active': 'true',
    });
    final hits = parseAutocomplete(await _get(uri));
    _searchCache[key] = hits;
    return hits;
  }

  @override
  Future<SpeciesLookupResult> resolve(
    int taxonId, {
    required String locale,
  }) async {
    final code = locale.toLowerCase();
    final key = '$code|$taxonId';
    final cached = _resolveCache[key];
    if (cached != null) return cached;

    final uri = Uri.https(_host, '$_taxonPath/$taxonId', {'locale': code});
    final detail = parseTaxonDetail(await _get(uri));
    final taxonomyClass = detail.ancestors
        .where((a) => a.rank == 'class')
        .map((a) => a.name)
        .firstOrNull;
    final result = SpeciesLookupResult(
      taxonId: detail.taxonId,
      commonName: detail.commonName ?? detail.scientificName,
      scientificName: detail.scientificName,
      category: speciesCategoryFromAncestry(detail.ancestors),
      taxonomyClass: taxonomyClass,
    );
    _resolveCache[key] = result;
    return result;
  }

  Future<String> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(_timeout);
    } on TimeoutException {
      throw const SpeciesLookupException(SpeciesLookupErrorKind.timeout);
    } on SocketException catch (e) {
      throw SpeciesLookupException(SpeciesLookupErrorKind.offline, e.message);
    } on http.ClientException catch (e) {
      throw SpeciesLookupException(SpeciesLookupErrorKind.offline, e.message);
    }
    if (response.statusCode != 200) {
      throw SpeciesLookupException(
        SpeciesLookupErrorKind.server,
        'HTTP ${response.statusCode}',
      );
    }
    return response.body;
  }
}
