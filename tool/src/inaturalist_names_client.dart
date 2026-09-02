import 'dart:convert';
import 'dart:io';

const String inaturalistUserAgent = 'Submersion/1.0 (https://submersion.app)';

/// Resolves a scientific name to its iNaturalist taxon with every name
/// attached (`all_names=true`). One request per species; the caller paces.
class InaturalistNamesClient {
  InaturalistNamesClient({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  /// The taxon whose `name` or `matched_term` equals [scientificName] (or
  /// the taxon [taxonId] when given), or null when iNaturalist has no such
  /// species. No rank filter, so a subspecies such as the red-eared slider
  /// resolves too.
  Future<Map<String, dynamic>?> taxonByScientificName(
    String scientificName, {
    int? taxonId,
  }) async {
    final uri = taxonId != null
        ? Uri.parse(
            'https://api.inaturalist.org/v1/taxa/$taxonId?all_names=true',
          )
        : Uri.parse(
            'https://api.inaturalist.org/v1/taxa'
            '?q=${Uri.encodeQueryComponent(scientificName)}'
            '&all_names=true&per_page=30',
          );
    for (var attempt = 1; attempt <= 3; attempt++) {
      final request = await _client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, inaturalistUserAgent);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final results =
            ((jsonDecode(body) as Map<String, dynamic>)['results'] as List)
                .cast<Map<String, dynamic>>();
        if (taxonId != null) return results.firstOrNull;
        // The exact name first: a subspecies can carry the species name as
        // its matched_term and outrank it. Then a synonym query (a genus
        // iNaturalist has since split, say), which comes back under the
        // accepted name with the query in matched_term.
        // Among exact matches, a species-level rank beats a "complex" or a
        // genus that shares the name (Micropterus dolomieu has both).
        const speciesRanks = {'species', 'subspecies', 'variety', 'form'};
        for (final r in results) {
          if (r['name'] == scientificName && speciesRanks.contains(r['rank'])) {
            return r;
          }
        }
        for (final r in results) {
          if (r['name'] == scientificName) return r;
        }
        for (final r in results) {
          if (r['matched_term'] == scientificName) return r;
        }
        return null;
      }
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    }
    throw HttpException('iNaturalist failed for $scientificName');
  }

  void close() => _client.close();
}
