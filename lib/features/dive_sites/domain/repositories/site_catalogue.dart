import 'package:submersion/features/dive_sites/domain/entities/catalogue_bounds.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_withdrawal.dart';
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
  ///
  /// With [mapPlacedOnly], only records whose position was read off a map
  /// ([CatalogueSite.positionFromMap]), and [limit] counts those alone:
  /// matching reads them further out than the rest, where nearer records
  /// would otherwise fill the limit first.
  Future<List<CatalogueSite>> near(
    GeoPoint point, {
    required double radiusMeters,
    int limit = 500,
    CatalogueKind? kind,
    bool mapPlacedOnly = false,
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
  /// then register records, each kind nearest the middle of the box first.
  /// `truncated` says the box held more.
  ///
  /// Only records of [kinds] are read, and [limit] and `truncated` speak
  /// of those alone: a map that draws dive sites only is not cut short by
  /// the wrecks around them. With no kind nothing is read.
  Future<CatalogueBoundsResult> inBounds(
    CatalogueBounds bounds, {
    int limit = 1500,
    Set<CatalogueKind> kinds = const {
      CatalogueKind.site,
      CatalogueKind.register,
    },
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

  /// The located records that carry one of [names], give or take case,
  /// accents, punctuation and spacing, grouped by `catalogueNameKey`. A
  /// name no record carries has no entry, and a blank name is not asked.
  ///
  /// Unlike [search] it matches whole names and has no limit: it answers
  /// "which of these sites of the diver's are in the catalogue?" for all
  /// of them in one read, however many there are.
  Future<Map<String, List<CatalogueSite>>> namedMany(Iterable<String> names);

  /// The source a record names in its `source`.
  Future<CatalogueSource?> source(String key);

  /// Why the record [id] was withdrawn from the catalogue, or null when
  /// the catalogue lists no withdrawal for it.
  Future<CatalogueWithdrawal?> withdrawal(String id);
}
