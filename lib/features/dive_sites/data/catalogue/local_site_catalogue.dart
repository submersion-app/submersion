import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_row_mapper.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_bounds.dart';
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
    CatalogueKind? kind,
  }) => _read(const [], (db) async {
    final rows = await (db.select(
      db.siteCatalogueEntries,
    )..where((t) => _ofKind(t, kind, _inBox(t, point, radiusMeters)))).get();
    // Rows become sites only once the distance check and the limit have
    // chosen them: decoding a row's lists is the costly part of a read.
    return _nearestFirst(
      rows,
      point,
      radiusMeters,
    ).take(limit).map(catalogueSiteFromRow).toList();
  });

  @override
  Future<int> countNear(
    GeoPoint point, {
    required double radiusMeters,
    required CatalogueKind kind,
  }) => _read(0, (db) async {
    final t = db.siteCatalogueEntries;
    // Only the two coordinates are read: the box is what the index
    // answers, and its corners are cut here without decoding a row.
    final rows =
        await (db.selectOnly(t)
              ..addColumns([t.latitude, t.longitude])
              ..where(_ofKind(t, kind, _inBox(t, point, radiusMeters))))
            .get();
    return rows
        .where(
          (row) =>
              distanceMeters(
                point,
                GeoPoint(row.read(t.latitude)!, row.read(t.longitude)!),
              ) <=
              radiusMeters,
        )
        .length;
  });

  @override
  Future<CatalogueBoundsResult> inBounds(
    CatalogueBounds bounds, {
    int limit = 1500,
  }) => _read((sites: const <CatalogueSite>[], truncated: false), (db) async {
    Expression<bool> inside($SiteCatalogueEntriesTable t, CatalogueKind kind) =>
        _ofKind(t, kind, _inBounds(t, bounds));

    // One more than the limit is asked for, to learn that there was more.
    final sites =
        await (db.select(db.siteCatalogueEntries)
              ..where((t) => inside(t, CatalogueKind.site))
              ..limit(limit + 1))
            .get();
    if (sites.length > limit) {
      return (
        sites: sites.take(limit).map(catalogueSiteFromRow).toList(),
        truncated: true,
      );
    }
    final room = limit - sites.length;
    final registers =
        await (db.select(db.siteCatalogueEntries)
              ..where((t) => inside(t, CatalogueKind.register))
              ..orderBy([(t) => OrderingTerm.asc(_farFrom(bounds.center))])
              ..limit(room + 1))
            .get();
    return (
      sites: [
        ...sites,
        ...registers.take(room),
      ].map(catalogueSiteFromRow).toList(),
      truncated: registers.length > room,
    );
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

    // The catalogue names countries in English, and a diver types the name
    // their own language gives one: a query that names a country, in any
    // language, also finds the sites carrying that country's code (#4520).
    final countryCodes = countryCodesMatching(query);

    Expression<bool> matches($SiteCatalogueEntriesTable t) {
      final everyWord = words
          .map<Expression<bool>>(
            (word) => t.searchText.like(
              '%${_escapeLike(word)}%',
              escapeChar: _likeEscape,
            ),
          )
          .reduce((a, b) => a & b);
      if (countryCodes.isEmpty) return everyWord;
      return everyWord | t.countryCode.isIn(countryCodes);
    }

    // The dive's area: every match in it, read whole so the box's corners
    // can be cut by a real distance.
    final inArea = <SiteCatalogueRow>[];
    if (areaFirst != null) {
      final rows =
          await (db.select(db.siteCatalogueEntries)
                ..where(
                  (t) => matches(t) & _inBox(t, areaFirst, areaRadiusMeters),
                )
                ..orderBy([_sitesFirst, ..._byName]))
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
                _sitesFirst,
                ..._byName,
              ])
              // Enough to fill the page even if every area match repeats.
              ..limit(limit + areaIds.length))
            .get();
    final elsewhere = [
      for (final row in everywhere)
        if (!areaIds.contains(row.id)) row,
    ];

    // Sites the diver named come before sites that are only in a place, a
    // sea or a country of that name; within each, the dive's area leads,
    // and both queries already put dive sites before register records.
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

/// Dive sites before register records: a search for a country or a sea
/// lists the places people dive there before its charted wrecks.
OrderingTerm _sitesFirst($SiteCatalogueEntriesTable t) =>
    OrderingTerm.asc(t.kind.equals(CatalogueKind.register.name));

/// [filter], narrowed to records of [kind] when one is asked for.
Expression<bool> _ofKind(
  $SiteCatalogueEntriesTable t,
  CatalogueKind? kind,
  Expression<bool> filter,
) => kind == null ? filter : t.kind.equals(kind.name) & filter;

/// Rows whose coordinates fall in [bounds], either side of the
/// antimeridian when the box crosses it.
Expression<bool> _inBounds(
  $SiteCatalogueEntriesTable t,
  CatalogueBounds bounds,
) {
  final latitude = t.latitude.isBetweenValues(bounds.south, bounds.north);
  final longitude = bounds.crossesAntimeridian
      ? t.longitude.isBiggerOrEqualValue(bounds.west) |
            t.longitude.isSmallerOrEqualValue(bounds.east)
      : t.longitude.isBetweenValues(bounds.west, bounds.east);
  return latitude & longitude;
}

/// How far a row is from [center], in squared degrees, the short way round
/// the globe: enough to order the rows of one map by.
Expression<double> _farFrom(GeoPoint center) {
  final lat = center.latitude;
  final lon = center.longitude;
  return CustomExpression<double>(
    '((latitude - ($lat)) * (latitude - ($lat)) + '
    'min(abs(longitude - ($lon)), 360 - abs(longitude - ($lon))) * '
    'min(abs(longitude - ($lon)), 360 - abs(longitude - ($lon))))',
  );
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

/// The [rows] within [radiusMeters] of [center], nearest first. Every row
/// comes from [_inBox], so it has coordinates.
Iterable<SiteCatalogueRow> _nearestFirst(
  List<SiteCatalogueRow> rows,
  GeoPoint center,
  double radiusMeters,
) {
  final inside = [
    for (final row in rows)
      if (distanceMeters(center, GeoPoint(row.latitude!, row.longitude!))
          case final distance when distance <= radiusMeters)
        (row: row, distance: distance),
  ]..sort((a, b) => a.distance.compareTo(b.distance));
  return inside.map((entry) => entry.row);
}

/// [word] with LIKE's wildcards made literal, so a search for "100%" finds
/// that text and not everything.
String _escapeLike(String word) => word
    .replaceAll(_likeEscape, '$_likeEscape$_likeEscape')
    .replaceAll('%', '$_likeEscape%')
    .replaceAll('_', '${_likeEscape}_');
