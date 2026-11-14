import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_parser.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_bounds.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/repositories/site_catalogue.dart';

/// An in-memory [SiteCatalogue] with the real one's rules, for tests that
/// are not about the local cache database.
///
/// [sites] may be changed between calls, which is how a test shows a
/// catalogue that finishes loading. The call counters let a test assert
/// that a screen did, or did not, ask.
class FakeSiteCatalogue implements SiteCatalogue {
  FakeSiteCatalogue([
    List<CatalogueSite> sites = const [],
    this.sources = const {},
  ]) : sites = List.of(sites);

  List<CatalogueSite> sites;
  final Map<String, CatalogueSource> sources;

  int nearCalls = 0;
  int searchCalls = 0;
  int byIdCalls = 0;
  int countNearCalls = 0;
  int inBoundsCalls = 0;

  /// The bounds of every [inBounds] call, in order.
  final List<CatalogueBounds> boundsAsked = [];

  /// The query of every [search] call, in order.
  final List<String> searches = [];

  @override
  Future<List<CatalogueSite>> near(
    GeoPoint point, {
    required double radiusMeters,
    int limit = 500,
    CatalogueKind? kind,
  }) async {
    nearCalls++;
    final inside = [
      for (final site in sites)
        if (kind == null || site.kind == kind)
          if (site.location case final location?)
            if (distanceMeters(point, location) <= radiusMeters)
              (site: site, distance: distanceMeters(point, location)),
    ]..sort((a, b) => a.distance.compareTo(b.distance));
    return [for (final entry in inside.take(limit)) entry.site];
  }

  @override
  Future<int> countNear(
    GeoPoint point, {
    required double radiusMeters,
    required CatalogueKind kind,
  }) async {
    countNearCalls++;
    return sites
        .where(
          (site) =>
              site.kind == kind &&
              site.location != null &&
              distanceMeters(point, site.location!) <= radiusMeters,
        )
        .length;
  }

  @override
  Future<CatalogueBoundsResult> inBounds(
    CatalogueBounds bounds, {
    int limit = 1500,
  }) async {
    inBoundsCalls++;
    boundsAsked.add(bounds);
    final inside = [
      for (final site in sites)
        if (site.location case final location? when bounds.contains(location))
          site,
    ];
    final center = bounds.center;
    final ordered = [
      ...inside.where((site) => site.kind == CatalogueKind.site),
      ...inside.where((site) => site.kind == CatalogueKind.register).toList()
        ..sort(
          (a, b) => distanceMeters(
            center,
            a.location!,
          ).compareTo(distanceMeters(center, b.location!)),
        ),
    ];
    return (
      sites: ordered.take(limit).toList(),
      truncated: ordered.length > limit,
    );
  }

  @override
  Future<List<CatalogueSite>> search(
    String query, {
    GeoPoint? areaFirst,
    double areaRadiusMeters = 50000,
    int limit = 50,
  }) async {
    searchCalls++;
    searches.add(query);
    final words = normalize(
      query,
    ).split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return const [];

    // A query that names a country, in any language, also finds the sites
    // carrying that country's code.
    final countryCodes = countryCodesMatching(query);
    final matches = [
      for (final site in sites)
        if (words.every(catalogueSearchText(site).contains) ||
            countryCodes.contains(site.countryCode))
          site,
    ]..sort(_byName);
    bool inArea(CatalogueSite site) =>
        areaFirst != null &&
        site.location != null &&
        distanceMeters(areaFirst, site.location!) <= areaRadiusMeters;
    // Sites matched by their own name first, then those matched only by a
    // place or a sea; the area leads within each.
    bool byName(CatalogueSite site) {
      final text = catalogueSearchText(site);
      final name = text.substring(0, text.indexOf(kCatalogueNameEnd));
      return words.every(name.contains);
    }

    // Within each group, dive sites before register records.
    List<CatalogueSite> group(bool Function(CatalogueSite) test) {
      final members = matches.where(test).toList();
      return [
        ...members.where((site) => site.kind == CatalogueKind.site),
        ...members.where((site) => site.kind == CatalogueKind.register),
      ];
    }

    return [
      ...group((site) => byName(site) && inArea(site)),
      ...group((site) => byName(site) && !inArea(site)),
      ...group((site) => !byName(site) && inArea(site)),
      ...group((site) => !byName(site) && !inArea(site)),
    ].take(limit).toList();
  }

  @override
  Future<CatalogueSite?> byId(String id) async {
    byIdCalls++;
    return sites.where((site) => site.id == id).firstOrNull;
  }

  @override
  Future<CatalogueSource?> source(String key) async => sources[key];
}

/// The real catalogue's order: folded name first (the search text begins
/// with it), the raw name and the id to settle ties.
int _byName(CatalogueSite a, CatalogueSite b) {
  final byText = catalogueSearchText(a).compareTo(catalogueSearchText(b));
  if (byText != 0) return byText;
  final byName = a.name.compareTo(b.name);
  return byName != 0 ? byName : a.id.compareTo(b.id);
}
