import 'dart:convert';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/site_type_seed.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/dive_sites/data/catalogue/catalogue_enum_names.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A catalogue file, read.
class ParsedSiteCatalogue {
  final int format;
  final List<CatalogueSite> sites;
  final List<CatalogueSource> sources;

  const ParsedSiteCatalogue({
    required this.format,
    required this.sites,
    required this.sources,
  });
}

/// Names the sea at a position, or null when it is inland or unknown.
typedef SeaNamer = String? Function(double latitude, double longitude);

/// Site types that are fresh water wherever they are. The sea table
/// reaches a few kilometres inland, to catch sites recorded from a beach,
/// and one of these that close to a coast is still not in the sea.
const _inlandTypeIds = {'lake', 'quarry', 'river', 'spring', 'cenote', 'pool'};

/// Reads the text of `assets/data/site_catalogue.json`.
///
/// Forgiving by record: a record without an id, a name or a source is
/// skipped, and a value this build does not know (a site type from a newer
/// catalogue, a number written as text) is dropped while the record is
/// kept. Only a file that is not a catalogue at all throws
/// [FormatException].
///
/// With [seaAt], a located record that names no body of water takes the
/// sea at its position, so a search for "Red Sea" finds the sites in it
/// and an adopted site starts with its water named. The file itself
/// carries no sea names: OpenStreetMap, its source, has none.
///
/// Top-level so it can run through `compute`.
ParsedSiteCatalogue parseSiteCatalogue(String json, {SeaNamer? seaAt}) {
  final Object? decoded = jsonDecode(json);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('The site catalogue is not a JSON object');
  }
  final rawSites = decoded['sites'];
  if (rawSites is! List) {
    throw const FormatException('The site catalogue has no sites list');
  }
  final metadata = decoded['metadata'];
  final meta = metadata is Map<String, dynamic>
      ? metadata
      : const <String, dynamic>{};

  return ParsedSiteCatalogue(
    format: _int(meta['format']) ?? 0,
    sites: [
      for (final raw in rawSites)
        if (raw is Map<String, dynamic>) ?_site(raw, seaAt),
    ],
    sources: [
      if (meta['sources'] case final Map<String, dynamic> sources)
        for (final entry in sources.entries)
          if (entry.value case final Map<String, dynamic> raw)
            ?_source(entry.key, raw),
    ],
  );
}

/// What a search can match of [site], folded the way the site picker folds
/// the diver's own sites (`normalizedSiteSearchText`): its name and where
/// it is, down to the sea.
String catalogueSearchText(CatalogueSite site) => normalize(
  [
        site.name,
        site.country,
        site.region,
        site.locality,
        site.island,
        site.bodyOfWater,
      ]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' '),
);

CatalogueSite? _site(Map<String, dynamic> raw, SeaNamer? seaAt) {
  final id = _text(raw['id']);
  final name = _text(raw['name']);
  final source = _text(raw['source']);
  if (id == null || name == null || source == null) return null;

  final location = _location(raw['lat'], raw['lon']);
  final waterType = waterTypesByName[raw['water_type']];
  final typeIds = [
    for (final type in _strings(raw['types']))
      if (kBuiltInSiteTypeIds.contains(type)) type,
  ];

  return CatalogueSite(
    id: id,
    name: name,
    location: location,
    countryCode: _text(raw['country_code']),
    country: _text(raw['country']),
    region: _text(raw['region']),
    locality: _text(raw['locality']),
    island: _text(raw['island']),
    bodyOfWater:
        _text(raw['body_of_water']) ??
        _sea(location, waterType, typeIds, seaAt),
    waterType: waterType,
    minDepth: _double(raw['min_depth_m']),
    maxDepth: _double(raw['max_depth_m']),
    typeIds: typeIds,
    entryMethods: [
      for (final entry in _strings(raw['entry'])) ?entryMethodsByName[entry],
    ],
    features: _strings(raw['features']),
    difficulty: siteDifficultiesByName[raw['difficulty']],
    hazards: _text(raw['hazards']),
    description: _text(raw['description']),
    website: _text(raw['website']),
    source: source,
    sourceRef: _text(raw['source_ref']),
    trust: catalogueTrustByName[raw['trust']] ?? CatalogueTrust.verified,
  );
}

/// The sea a record with no body of water of its own lies in, or null:
/// for a record with no position, and for one the catalogue says is fresh
/// water.
String? _sea(
  GeoPoint? location,
  WaterType? waterType,
  List<String> typeIds,
  SeaNamer? seaAt,
) {
  if (location == null || seaAt == null) return null;
  if (waterType == WaterType.fresh || typeIds.any(_inlandTypeIds.contains)) {
    return null;
  }
  return seaAt(location.latitude, location.longitude);
}

CatalogueSource? _source(String key, Map<String, dynamic> raw) {
  final name = _text(raw['name']);
  final licence = _text(raw['licence']);
  if (name == null || licence == null) return null;
  return CatalogueSource(
    key: key,
    name: name,
    licence: licence,
    licenceUrl: _text(raw['licence_url']),
    credit: _text(raw['credit']) ?? name,
  );
}

GeoPoint? _location(Object? lat, Object? lon) {
  final latitude = _double(lat);
  final longitude = _double(lon);
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  return GeoPoint(latitude, longitude);
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _double(Object? value) => value is num ? value.toDouble() : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

List<String> _strings(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is String) item,
];
