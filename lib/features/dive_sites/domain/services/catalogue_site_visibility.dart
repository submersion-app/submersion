import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The catalogue records [userSites] were adopted from.
Set<String> linkedCatalogueIds(Iterable<DiveSite> userSites) => {
  for (final site in userSites) ?site.catalogueId,
};

/// The catalogue [sites] worth offering to a diver who has [userSites], in
/// their given order.
///
/// Two rules hide a record:
///
/// - **By link.** One of the diver's sites was adopted from it. A linked
///   site hides only its own record.
/// - **By position** (when [byPosition]). One of the diver's *unlinked*
///   sites lies within [radiusMeters] of it: a site made by hand, or
///   adopted before sites carried a link, that is very likely the same
///   place.
///
/// Linked sites take no part in the position rule on purpose. Hundreds of
/// catalogue records sit within 150 m of a different site ("Barracuda East"
/// and "Barracuda West"), and adopting one must not hide its neighbours.
///
/// Lists the diver browses by area pass `byPosition: true`. A search by
/// name passes false, so a site looked up by name can always be reached.
List<CatalogueSite> offerableCatalogueSites(
  List<CatalogueSite> sites,
  List<DiveSite> userSites, {
  required bool byPosition,
  double radiusMeters = 150,
}) {
  final linked = linkedCatalogueIds(userSites);
  final near = byPosition
      ? _NearbyIndex([
          for (final site in userSites)
            if (site.catalogueId == null) ?site.location,
        ], radiusMeters)
      : null;

  return [
    for (final site in sites)
      if (!linked.contains(site.id) &&
          !(near != null &&
              site.location != null &&
              near.hasPointNear(site.location!)))
        site,
  ];
}

/// Points bucketed into a coarse grid, so each catalogue site is tested
/// only against the diver's sites in its own and adjacent cells: near
/// linear instead of sites times sites.
class _NearbyIndex {
  _NearbyIndex(List<GeoPoint> points, this._radiusMeters) {
    for (final point in points) {
      (_grid[_key(_column(point.longitude), _row(point.latitude))] ??= []).add(
        point,
      );
    }
  }

  /// One degree comfortably exceeds any radius this is used with, at any
  /// latitude a dive site has, so a match can only fall in the same or an
  /// adjacent cell.
  static const _columns = 360;

  final double _radiusMeters;
  final Map<int, List<GeoPoint>> _grid = {};

  static int _column(double longitude) => longitude.floor();
  static int _row(double latitude) => latitude.floor();

  /// Columns wrap at the antimeridian: 179 E and 180 W are neighbours.
  static int _key(int column, int row) =>
      ((column % _columns) + _columns) % _columns * 1000 + (row + 500);

  bool hasPointNear(GeoPoint probe) {
    final column = _column(probe.longitude);
    final row = _row(probe.latitude);
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final bucket = _grid[_key(column + dx, row + dy)];
        if (bucket == null) continue;
        for (final point in bucket) {
          if (distanceMeters(probe, point) <= _radiusMeters) return true;
        }
      }
    }
    return false;
  }
}
