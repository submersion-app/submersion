import 'package:submersion/features/dive_sites/domain/entities/catalogue_bounds.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The built-in site catalogue, as every screen reads it.
///
/// Reads never throw: a catalogue that is not loaded yet, or cannot be
/// reached, answers as an empty one.
abstract interface class SiteCatalogue {
  /// Sites within [radiusMeters] of [point], nearest first. Sites without
  /// coordinates are never returned.
  ///
  /// With [kind], only records of that kind, and [limit] counts those
  /// alone: the picker lists dive sites and register records apart.
  Future<List<CatalogueSite>> near(
    GeoPoint point, {
    required double radiusMeters,
    int limit = 500,
    CatalogueKind? kind,
  });

  /// How many records of [kind] lie within [radiusMeters] of [point],
  /// without reading them: there can be thousands of register records
  /// where there are a dozen dive sites.
  Future<int> countNear(
    GeoPoint point, {
    required double radiusMeters,
    required CatalogueKind kind,
  });

  /// The sites in [bounds], for a map: at most [limit], dive sites first,
  /// then the register records nearest the middle of the box. `truncated`
  /// says the box held more.
  Future<CatalogueBoundsResult> inBounds(
    CatalogueBounds bounds, {
    int limit = 1500,
  });

  /// Sites whose name or place matches every word of [query].
  ///
  /// With [areaFirst], matches within [areaRadiusMeters] of it come first;
  /// the rest follow by name. Among matches that are otherwise equal, dive
  /// sites come before register records. A blank query matches nothing.
  Future<List<CatalogueSite>> search(
    String query, {
    GeoPoint? areaFirst,
    double areaRadiusMeters = 50000,
    int limit = 50,
  });

  Future<CatalogueSite?> byId(String id);

  /// The source a record names in its `source`.
  Future<CatalogueSource?> source(String key);
}
