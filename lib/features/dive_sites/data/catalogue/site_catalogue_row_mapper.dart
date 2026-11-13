import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The local cache row for [site], with its search text folded once here so
/// a search never folds a row.
SiteCatalogueEntriesCompanion catalogueSiteToRow(CatalogueSite site) =>
    SiteCatalogueEntriesCompanion.insert(
      id: site.id,
      name: site.name,
      searchText: catalogueSearchText(site),
      latitude: Value(site.location?.latitude),
      longitude: Value(site.location?.longitude),
      countryCode: Value(site.countryCode),
      country: Value(site.country),
      region: Value(site.region),
      locality: Value(site.locality),
      island: Value(site.island),
      bodyOfWater: Value(site.bodyOfWater),
      waterType: Value(site.waterType?.name),
      minDepth: Value(site.minDepth),
      maxDepth: Value(site.maxDepth),
      typeIds: Value(jsonEncode(site.typeIds)),
      entryMethods: Value(
        jsonEncode([for (final method in site.entryMethods) method.name]),
      ),
      features: Value(jsonEncode(site.features)),
      difficulty: Value(site.difficulty?.name),
      hazards: Value(site.hazards),
      description: Value(site.description),
      website: Value(site.website),
      source: site.source,
      sourceRef: Value(site.sourceRef),
      trust: Value(site.trust.name),
    );

/// The catalogue site a local cache row holds.
CatalogueSite catalogueSiteFromRow(SiteCatalogueRow row) => CatalogueSite(
  id: row.id,
  name: row.name,
  location: row.latitude != null && row.longitude != null
      ? GeoPoint(row.latitude!, row.longitude!)
      : null,
  countryCode: row.countryCode,
  country: row.country,
  region: row.region,
  locality: row.locality,
  island: row.island,
  bodyOfWater: row.bodyOfWater,
  waterType: WaterType.values.asNameMap()[row.waterType],
  minDepth: row.minDepth,
  maxDepth: row.maxDepth,
  typeIds: _strings(row.typeIds),
  entryMethods: [
    for (final name in _strings(row.entryMethods))
      ?EntryMethod.values.asNameMap()[name],
  ],
  features: _strings(row.features),
  difficulty: SiteDifficulty.values.asNameMap()[row.difficulty],
  hazards: row.hazards,
  description: row.description,
  website: row.website,
  source: row.source,
  sourceRef: row.sourceRef,
  trust:
      CatalogueTrust.values.asNameMap()[row.trust] ?? CatalogueTrust.verified,
);

/// The stored form of the catalogue's sources.
String encodeCatalogueSources(List<CatalogueSource> sources) => jsonEncode([
  for (final source in sources)
    {
      'key': source.key,
      'name': source.name,
      'licence': source.licence,
      'licence_url': source.licenceUrl,
      'credit': source.credit,
    },
]);

/// Reads [encodeCatalogueSources] back. Anything unreadable is no sources.
List<CatalogueSource> decodeCatalogueSources(String? stored) {
  if (stored == null) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(stored);
  } on FormatException {
    return const [];
  }
  return [
    if (decoded is List)
      for (final raw in decoded)
        if (raw case {
          'key': final String key,
          'name': final String name,
          'licence': final String licence,
          'credit': final String credit,
        })
          CatalogueSource(
            key: key,
            name: name,
            licence: licence,
            licenceUrl: raw['licence_url'] as String?,
            credit: credit,
          ),
  ];
}

List<String> _strings(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  return [
    if (decoded is List)
      for (final item in decoded)
        if (item is String) item,
  ];
}
