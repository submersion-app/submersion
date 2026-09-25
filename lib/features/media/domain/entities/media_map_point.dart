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

  /// The dive's site name, else the attached site's name, else null. For a
  /// site placement this is the site the item sits at; for a GPS placement
  /// it is the nearest known context.
  final String? placeLabel;

  MediaItem get item => entry.item;

  @override
  List<Object?> get props => [entry.item.id, point, placement, placeLabel];
}
