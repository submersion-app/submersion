import 'dart:convert';

import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';

/// Parses `GET /v1/taxa/autocomplete`. Every field the UI shows is read
/// leniently: a hit missing a common name or photo is still a hit.
List<SpeciesLookupHit> parseAutocomplete(String body) {
  final results = _results(body);
  return [for (final r in results) _hit(r)];
}

/// Parses `GET /v1/taxa/{id}`: the first result with its ancestry.
TaxonDetail parseTaxonDetail(String body) {
  final results = _results(body);
  if (results.isEmpty) {
    throw const SpeciesLookupException(
      SpeciesLookupErrorKind.malformed,
      'taxon response has no results',
    );
  }
  final r = results.first;
  try {
    final ancestors = <TaxonAncestor>[
      for (final a in (r['ancestors'] as List?) ?? const [])
        if (a is Map && a['rank'] is String && a['name'] is String)
          TaxonAncestor(a['rank'] as String, a['name'] as String),
    ];
    return TaxonDetail(
      taxonId: _int(r['id']),
      scientificName: r['name'] as String,
      commonName: _commonName(r),
      rank: r['rank'] as String,
      ancestors: ancestors,
    );
  } on TypeError catch (e) {
    throw SpeciesLookupException(
      SpeciesLookupErrorKind.malformed,
      e.toString(),
    );
  } on FormatException catch (e) {
    throw SpeciesLookupException(SpeciesLookupErrorKind.malformed, e.message);
  }
}

List<Map<String, dynamic>> _results(String body) {
  try {
    final decoded = jsonDecode(body);
    final results = (decoded as Map<String, dynamic>)['results'] as List?;
    return [
      for (final r in results ?? const [])
        if (r is Map<String, dynamic>) r,
    ];
  } on FormatException catch (e) {
    throw SpeciesLookupException(SpeciesLookupErrorKind.malformed, e.message);
  } on TypeError catch (e) {
    throw SpeciesLookupException(
      SpeciesLookupErrorKind.malformed,
      e.toString(),
    );
  }
}

SpeciesLookupHit _hit(Map<String, dynamic> r) {
  try {
    return SpeciesLookupHit(
      taxonId: _int(r['id']),
      scientificName: r['name'] as String,
      rank: r['rank'] as String,
      rankLevel: _int(r['rank_level']),
      commonName: _commonName(r),
      matchedTerm: r['matched_term'] as String?,
      observationCount: _int(r['observations_count'] ?? 0),
      photo: _photo(r['default_photo']),
    );
  } on TypeError catch (e) {
    throw SpeciesLookupException(
      SpeciesLookupErrorKind.malformed,
      e.toString(),
    );
  } on FormatException catch (e) {
    throw SpeciesLookupException(SpeciesLookupErrorKind.malformed, e.message);
  }
}

String? _commonName(Map<String, dynamic> r) {
  final preferred = r['preferred_common_name'] as String?;
  if (preferred != null && preferred.isNotEmpty) return preferred;
  final english = r['english_common_name'] as String?;
  if (english != null && english.isNotEmpty) return english;
  return null;
}

/// Only a photo with a licence is shown; null `license_code` means all
/// rights reserved.
SpeciesLookupPhoto? _photo(Object? raw) {
  if (raw is! Map) return null;
  if (raw['license_code'] == null) return null;
  final url = raw['square_url'] as String?;
  if (url == null) return null;
  return SpeciesLookupPhoto(
    squareUrl: url,
    attribution: (raw['attribution'] as String?) ?? '',
  );
}

/// A numeric field, whatever JSON type iNaturalist used for it. A string
/// that is not a number throws [FormatException] and a non-numeric type
/// [TypeError]; both callers turn either into the malformed lookup error.
int _int(Object? value) => switch (value) {
  final int i => i,
  final double d => d.round(),
  final String s => int.parse(s),
  _ => throw TypeError(),
};
