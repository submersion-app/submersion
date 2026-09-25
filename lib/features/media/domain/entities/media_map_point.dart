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

  /// A map-specific key: every field the map draws, orders by, places by, or
  /// resolves a thumbnail from, and nothing else.
  ///
  /// MediaMapNotifier treats an equal reload as "nothing changed" and keeps
  /// the list instance, which is what stops the cluster layer re-clustering
  /// and the place strip closing. Media-store bookkeeping (upload stamps,
  /// content hash and size, compression, verification and edit timestamps)
  /// is written row by row while a store drains and changes none of that, so
  /// it is deliberately left out. A favorite toggle (the cluster's
  /// representative), a new thumbnail, a source change or a move all still
  /// compare unequal.
  @override
  List<Object?> get props => [
    item.id,
    item.mediaType,
    item.isFavorite,
    item.takenAt,
    item.isOrphaned,
    item.sourceType,
    item.platformAssetId,
    item.cloudAssetId,
    item.filePath,
    item.localPath,
    item.bookmarkRef,
    item.url,
    item.remoteAssetId,
    item.connectorAccountId,
    item.thumbnailPath,
    entry.diveNumber,
    entry.diveDateTime,
    entry.siteName,
    point,
    placement,
    placeLabel,
  ];
}
