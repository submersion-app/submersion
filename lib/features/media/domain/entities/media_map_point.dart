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

  /// The whole item, not just its id: the map notifier treats an equal
  /// reload as "nothing changed" and keeps the list instance, so a favorite
  /// toggle (which changes a cluster's representative) or any other item
  /// edit must compare unequal.
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
