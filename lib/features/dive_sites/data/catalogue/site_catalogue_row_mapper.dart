import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/geocoding/sea_area_index.dart';
import 'package:submersion/features/dive_sites/data/catalogue/catalogue_enum_names.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_withdrawal.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A catalogue file as the rows the local cache stores.
class SiteCatalogueRows {
  const SiteCatalogueRows({
    required this.rows,
    required this.sources,
    required this.seaTableRead,
    this.withdrawn = '[]',
  });

  final List<SiteCatalogueEntriesCompanion> rows;

  /// The file's sources, already encoded for the meta table.
  final String sources;

  /// The file's withdrawn records, already encoded for the meta table.
  final String withdrawn;

  /// Whether a sea table was given and could be parsed. False leaves every
  /// site without a sea name; the importer says so in the log.
  final bool seaTableRead;
}

/// What [buildSiteCatalogueRows] reads: the catalogue file and, when it
/// could be read, the sea table (`assets/data/sea_areas.json`) that names
/// each site's sea.
typedef SiteCatalogueRowsInput = ({String catalogue, String? seaAreas});

/// Reads a catalogue file into rows. Top-level so the importer can run it
/// through `compute`, keeping the parse, the sea lookups, the search-text
/// folding and the list encoding of every record off the UI isolate.
SiteCatalogueRows buildSiteCatalogueRows(SiteCatalogueRowsInput input) {
  final seas = _seaIndex(input.seaAreas);
  final parsed = parseSiteCatalogue(input.catalogue, seaAt: seas?.nameAt);
  return SiteCatalogueRows(
    rows: [for (final site in parsed.sites) catalogueSiteToRow(site)],
    sources: encodeCatalogueSources(parsed.sources),
    seaTableRead: seas != null,
    withdrawn: encodeCatalogueWithdrawals(parsed.withdrawn),
  );
}

/// The sea table, or null when it is missing or unreadable. Sea names are
/// an extra: the catalogue then loads without them, and
/// [SiteCatalogueRows.seaTableRead] carries the fact back to the importer,
/// which can log where this isolate cannot.
SeaAreaIndex? _seaIndex(String? seaAreas) {
  if (seaAreas == null) return null;
  try {
    return SeaAreaIndex.fromJson(jsonDecode(seaAreas) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

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
      kind: Value(site.kind.name),
      positionFrom: Value(site.positionFromMap ? 'map' : null),
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
  waterType: waterTypesByName[row.waterType],
  minDepth: row.minDepth,
  maxDepth: row.maxDepth,
  typeIds: _strings(row.typeIds),
  entryMethods: [
    for (final name in _strings(row.entryMethods)) ?entryMethodsByName[name],
  ],
  features: _strings(row.features),
  difficulty: siteDifficultiesByName[row.difficulty],
  hazards: row.hazards,
  description: row.description,
  website: row.website,
  source: row.source,
  sourceRef: row.sourceRef,
  trust: catalogueTrustByName[row.trust] ?? CatalogueTrust.verified,
  kind: catalogueKindsByName[row.kind] ?? CatalogueKind.site,
  positionFromMap: row.positionFrom == 'map',
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

/// The stored form of the catalogue's withdrawn records.
String encodeCatalogueWithdrawals(List<CatalogueWithdrawal> withdrawn) =>
    jsonEncode([
      for (final w in withdrawn)
        {
          'id': w.id,
          'reason': catalogueWithdrawalReasonName(w.reason),
          'date': w.date,
          'replaced_by': ?w.replacedBy,
        },
    ]);

/// Reads [encodeCatalogueWithdrawals] back. Anything unreadable is none.
List<CatalogueWithdrawal> decodeCatalogueWithdrawals(String? stored) {
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
        if (raw case {'id': final String id})
          ?catalogueWithdrawalFromJson(id, raw),
  ];
}

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
