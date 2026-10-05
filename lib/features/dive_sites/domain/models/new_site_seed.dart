import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// What a brand-new site form starts with when another screen opens it, such
/// as the site picker's "New Dive Site" button seeding the dive's GPS and the
/// text the diver searched for (issue #1501).
///
/// Travels as the `/sites/new` route's `extra`.
class NewSiteSeed extends Equatable {
  const NewSiteSeed({this.location, this.name});

  /// Reads the `/sites/new` route's `extra`: a [NewSiteSeed] as is, a bare
  /// [GeoPoint] as a location-only seed, and anything else as no seed.
  factory NewSiteSeed.fromRouteExtra(Object? extra) => switch (extra) {
    final NewSiteSeed seed => seed,
    final GeoPoint location => NewSiteSeed(location: location),
    _ => const NewSiteSeed(),
  };

  /// Fills the coordinate fields, which then reverse-geocode the place names.
  final GeoPoint? location;

  /// Fills the site name field.
  final String? name;

  NewSiteSeed copyWith({GeoPoint? location, String? name}) =>
      NewSiteSeed(location: location ?? this.location, name: name ?? this.name);

  @override
  List<Object?> get props => [location, name];
}
