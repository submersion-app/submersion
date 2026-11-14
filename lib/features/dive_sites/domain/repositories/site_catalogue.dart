import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The built-in site catalogue, as every screen reads it.
///
/// Reads never throw: a catalogue that is not loaded yet, or cannot be
/// reached, answers as an empty one.
abstract interface class SiteCatalogue {
  /// Sites within [radiusMeters] of [point], nearest first. Sites without
  /// coordinates are never returned.
  Future<List<CatalogueSite>> near(
    GeoPoint point, {
    required double radiusMeters,
    int limit = 500,
  });

  /// Sites whose name or place matches every word of [query].
  ///
  /// With [areaFirst], matches within [areaRadiusMeters] of it come first;
  /// the rest follow by name. A blank query matches nothing.
  Future<List<CatalogueSite>> search(
    String query, {
    GeoPoint? areaFirst,
    double areaRadiusMeters = 50000,
    int limit = 50,
  });

  Future<CatalogueSite?> byId(String id);

  /// Every site that has coordinates, for the map overlay.
  Future<List<CatalogueSite>> allWithCoordinates();

  /// The source a record names in its `source`.
  Future<CatalogueSource?> source(String key);
}
