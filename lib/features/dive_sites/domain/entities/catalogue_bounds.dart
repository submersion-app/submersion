import 'package:equatable/equatable.dart';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A box of latitude and longitude the catalogue is read by: what a map
/// shows.
///
/// [west] greater than [east] means the box crosses the antimeridian: it
/// runs east from [west], over 180 degrees, to [east].
class CatalogueBounds extends Equatable {
  const CatalogueBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  /// Whether the box runs over the antimeridian.
  bool get crossesAntimeridian => west > east;

  /// The middle of the box, the short way round.
  GeoPoint get center {
    final span = crossesAntimeridian ? east - west + 360 : east - west;
    return GeoPoint((south + north) / 2, normalizeLongitude(west + span / 2));
  }

  /// Whether [point] lies in the box, edges included.
  bool contains(GeoPoint point) {
    if (point.latitude < south || point.latitude > north) return false;
    return crossesAntimeridian
        ? point.longitude >= west || point.longitude <= east
        : point.longitude >= west && point.longitude <= east;
  }

  @override
  List<Object?> get props => [south, west, north, east];
}

/// The catalogue sites in a [CatalogueBounds], and whether the box held
/// more than the limit allowed back.
typedef CatalogueBoundsResult = ({List<CatalogueSite> sites, bool truncated});
