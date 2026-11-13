import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
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

    final inArea = <CatalogueSite>[];
    if (areaFirst != null) {
      final rows =
          await (db.select(db.siteCatalogueEntries)
                ..where(
                  (t) => matches(t) & _inBox(t, areaFirst, areaRadiusMeters),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
              .get();
      // The box has corners the circle does not: cut them here.
      inArea.addAll(
        rows
            .map(catalogueSiteFromRow)
            .where(
              (site) =>
                  distanceMeters(areaFirst, site.location!) <= areaRadiusMeters,
            ),
      );
    }

    final areaIds = {for (final site in inArea) site.id};
    final elsewhere =
        await (db.select(db.siteCatalogueEntries)
              ..where(matches)
              ..orderBy([(t) => OrderingTerm.asc(t.name)])
              // Enough to fill the page even if every area match repeats.
              ..limit(limit + areaIds.length))
            .get();

    return [
      ...inArea,
      for (final row in elsewhere)
        if (!areaIds.contains(row.id)) catalogueSiteFromRow(row),
    ].take(limit).toList();
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
