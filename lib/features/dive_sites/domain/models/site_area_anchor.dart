import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Where a dive with no GPS of its own probably was, taken from a dive
/// logged around the same time: the point "near here" is measured from in
/// the site picker.
///
/// An inferred place, not a measured one. A list built on it is sorted by
/// name, with no distances shown: distance from a neighbouring dive's site
/// says little about this dive.
class SiteAreaAnchor extends Equatable {
  const SiteAreaAnchor({required this.point, this.placeLabel});

  final GeoPoint point;

  /// The neighbouring site's island, else its region, else its country;
  /// null when it names none.
  final String? placeLabel;

  @override
  List<Object?> get props => [point, placeLabel];
}
