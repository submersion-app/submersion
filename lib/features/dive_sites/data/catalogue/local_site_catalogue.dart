import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_row_mapper.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/repositories/site_catalogue.dart';

const _log = LoggerService('LocalSiteCatalogue');

/// The escape character for LIKE patterns built from typed text.
const _likeEscape = r'\';

/// The built-in site catalogue, read from the local cache database the
/// importer fills.
///
/// Every read answers as an empty catalogue when the database is not open
/// or a query fails: built-in sites are a convenience, and no screen should
/// break for want of them.
class LocalSiteCatalogue implements SiteCatalogue {
  LocalSiteCatalogue({LocalCacheDatabase? database}) : _database = database;

  final LocalCacheDatabase? _database;

  @override
  Future<List<CatalogueSite>> near(
    GeoPoint point, {
    required double radiusMeters,
    int limit = 500,
  }) => _read(const [], (db) async {
    final rows = await (db.select(
      db.siteCatalogueEntries,
    )..where((t) => _inBox(t, point, radiusMeters))).get();
    return _nearestFirst(rows, point, radiusMeters).take(limit).toList();
  });

  @override
  Future<List<CatalogueSite>> search(
    String query, {
    GeoPoint? areaFirst,
    double areaRadiusMeters = 50000,
    int limit = 50,
  }) => _read(const [], (db) async {
    // Split exactly as SiteQuery splits a picker query, so the built-in
    // results obey the same "every word" rule as the diver's own sites.
    final words = normalize(
      query,
    ).split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return const [];

    Expression<bool> matches($SiteCatalogueEntriesTable t) => words
        .map<Expression<bool>>(
          (word) => t.searchText.like(
            '%${_escapeLike(word)}%',
            escapeChar: _likeEscape,
          ),
        )
        .reduce((a, b) => a & b);

    // The dive's area: every match in it, read whole so the box's corners
    // can be cut by a real distance.
    final inArea = <SiteCatalogueRow>[];
    if (areaFirst != null) {
      final rows =
          await (db.select(db.siteCatalogueEntries)
                ..where(
                  (t) => matches(t) & _inBox(t, areaFirst, areaRadiusMeters),
                )
                ..orderBy(_byName))
              .get();
      inArea.addAll(
        rows.where(
          (row) =>
              distanceMeters(
                areaFirst,
                GeoPoint(row.latitude!, row.longitude!),
              ) <=
              areaRadiusMeters,
        ),
      );
    }

    // Everywhere: name matches first, so the limit keeps "Sea Tiger" and
    // not the first fifty of the 1,600 sites that merely lie in a sea.
    final areaIds = {for (final row in inArea) row.id};
    final everywhere =
        await (db.select(db.siteCatalogueEntries)
              ..where(matches)
              ..orderBy([
                (t) => OrderingTerm.desc(_inName(t, words)),
                ..._byName,
              ])
              // Enough to fill the page even if every area match repeats.
              ..limit(limit + areaIds.length))
            .get();
    final elsewhere = [
      for (final row in everywhere)
        if (!areaIds.contains(row.id)) row,
    ];

    // Sites the diver named come before sites that are only in a place or
    // a sea of that name; within each, the dive's area leads.
    bool byName(SiteCatalogueRow row) => _nameMatches(row.searchText, words);
    return [
      ...inArea.where(byName),
      ...elsewhere.where(byName),
      ...inArea.whereNot(byName),
      ...elsewhere.whereNot(byName),
    ].take(limit).map(catalogueSiteFromRow).toList();
  });

  @override
  Future<CatalogueSite?> byId(String id) => _read(null, (db) async {
    final row = await (db.select(
      db.siteCatalogueEntries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : catalogueSiteFromRow(row);
  });

  @override
  Future<List<CatalogueSite>> allWithCoordinates() => _read(const [], (
    db,
  ) async {
    final rows = await (db.select(
      db.siteCatalogueEntries,
    )..where((t) => t.latitude.isNotNull() & t.longitude.isNotNull())).get();
    return rows.map(catalogueSiteFromRow).toList();
  });

  @override
  Future<CatalogueSource?> source(String key) => _read(null, (db) async {
    final row =
        await (db.select(db.siteCatalogueMeta)
              ..where((meta) => meta.key.equals(kSiteCatalogueMetaSources)))
            .getSingleOrNull();
    return decodeCatalogueSources(
      row?.value,
    ).where((source) => source.key == key).firstOrNull;
  });

  /// Runs [body] against the local cache, answering [fallback] when the
  /// database is not open (most widget tests, a failed startup step) or the
  /// query fails.
  Future<T> _read<T>(
    T fallback,
    Future<T> Function(LocalCacheDatabase db) body,
  ) async {
    final LocalCacheDatabase db;
    try {
      db = _database ?? LocalCacheDatabaseService.instance.database;
    } on StateError {
      return fallback;
    }
    try {
      return await body(db);
    } catch (error, stackTrace) {
      _log.warning(
        'A site catalogue read failed; answering as an empty catalogue',
        error: error,
        stackTrace: stackTrace,
      );
      return fallback;
    }
  }
}

/// Whether every word of a search is in the site's own name, not only in
/// its place or its sea: the search text holds the folded name up to
/// [kCatalogueNameEnd], and a word never contains that mark, so a word is
/// in the name exactly when it first appears before the mark.
Expression<bool> _inName($SiteCatalogueEntriesTable t, List<String> words) {
  Expression<int> at(String text) => FunctionCallExpression<int>('instr', [
    t.searchText,
    Variable.withString(text),
  ]);
  final nameEnd = at(kCatalogueNameEnd);
  return words
      .map<Expression<bool>>(
        (word) =>
            at(word).isBiggerThanValue(0) & at(word).isSmallerThan(nameEnd),
      )
      .reduce((a, b) => a & b);
}

/// [_inName] for a row already read. The two must agree: the query's order
/// decides which rows survive its limit, this decides where they are shown.
bool _nameMatches(String searchText, List<String> words) {
  final nameEnd = searchText.indexOf(kCatalogueNameEnd);
  if (nameEnd < 0) return false;
  final name = searchText.substring(0, nameEnd);
  return words.every(name.contains);
}

/// By name as a reader expects it: the search text begins with the folded
/// name, so "little shark" and "Épave" sort among the L and E names. SQLite
/// compares the raw name byte by byte, which would put both after "Zenobia".
/// The raw name and the id only settle ties.
final List<OrderingTerm Function($SiteCatalogueEntriesTable)> _byName = [
  (t) => OrderingTerm.asc(t.searchText),
  (t) => OrderingTerm.asc(t.name),
  (t) => OrderingTerm.asc(t.id),
];

/// Rows whose coordinates fall in the box around the circle of
/// [radiusMeters] about [center]. The box is what the index can answer;
/// callers cut its corners with a real distance afterwards.
///
/// So the box must hold the whole circle, and errs on the large side: a
/// degree of latitude is taken at its shortest, and the longitude span at
/// the edge of the box nearer the pole, where a degree of longitude is
/// shortest. A box that is a little small loses the sites at the rim.
///
/// A box that crosses the antimeridian becomes two longitude ranges: a
/// diver at 179.9 E is a few kilometres from a site at 179.9 W.
Expression<bool> _inBox(
  $SiteCatalogueEntriesTable t,
  GeoPoint center,
  double radiusMeters,
) {
  final latDelta = radiusMeters / metersPerDegreeLatitude;
  final polewardLatitude = math.min(center.latitude.abs() + latDelta, 90.0);
  final cosLat = math.cos(polewardLatitude * math.pi / 180).abs();
  // Near a pole a degree of longitude shrinks to nothing: take them all.
  final lonDelta = cosLat < 0.01 ? 180.0 : latDelta / cosLat;

  final latitude = t.latitude.isBetweenValues(
    center.latitude - latDelta,
    center.latitude + latDelta,
  );
  if (lonDelta >= 180) return latitude;

  final west = center.longitude - lonDelta;
  final east = center.longitude + lonDelta;
  final Expression<bool> longitude;
  if (west < -180) {
    longitude =
        t.longitude.isBiggerOrEqualValue(west + 360) |
        t.longitude.isSmallerOrEqualValue(east);
  } else if (east > 180) {
    longitude =
        t.longitude.isBiggerOrEqualValue(west) |
        t.longitude.isSmallerOrEqualValue(east - 360);
  } else {
    longitude = t.longitude.isBetweenValues(west, east);
  }
  return latitude & longitude;
}

Iterable<CatalogueSite> _nearestFirst(
  List<SiteCatalogueRow> rows,
  GeoPoint center,
  double radiusMeters,
) {
  final inside = [
    for (final site in rows.map(catalogueSiteFromRow))
      if (distanceMeters(center, site.location!) case final distance
          when distance <= radiusMeters)
        (site: site, distance: distance),
  ]..sort((a, b) => a.distance.compareTo(b.distance));
  return inside.map((entry) => entry.site);
}

/// [word] with LIKE's wildcards made literal, so a search for "100%" finds
/// that text and not everything.
String _escapeLike(String word) => word
    .replaceAll(_likeEscape, '$_likeEscape$_likeEscape')
    .replaceAll('%', '$_likeEscape%')
    .replaceAll('_', '${_likeEscape}_');
