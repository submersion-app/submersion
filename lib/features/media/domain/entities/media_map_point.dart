import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// Which source placed a media item on the map. The order of the values is
/// the fallback order.
enum MediaPlacement { ownGps, diveEntry, diveSite, attachedSite }

/// One located library item: where it sits on the map and why.
class MediaMapPoint extends Equatable {
  const MediaMapPoint({
    required this.entry,
    required this.point,
    required this.placement,
    this.placeLabel,
  });

  /// The item plus the dive header fields the grid already carries.
  final MediaLibraryEntry entry;

  final LatLng point;
  final MediaPlacement placement;

  /// The name of the site the item sits at for a site placement (the
  /// dive's site, or the attached site when that is where it was placed).
  /// For a GPS placement, the nearest known context: the dive's site, else
  /// the attached site. Null when no site is known.
  final String? placeLabel;

  MediaItem get item => entry.item;

  /// The whole item: the tile resolver's media-store fallback reads the
  /// content hash and upload stamps, so an upload must reach a mounted tile.
  /// Keeping clusters and the place strip steady across such a reload is
  /// MediaMapContent's job (it keys both on the layout, not on equality).
  @override
  List<Object?> get props => [
    entry.item,
    entry.diveNumber,
    entry.diveDateTime,
    entry.siteName,
    point,
    placement,
    placeLabel,
  ];
}
