import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';

/// Edge of a map thumbnail in logical pixels: 52dp of image inside a 2dp
/// border, the visual weight of the dive map's 50dp selected marker.
const double kMediaMapMarkerSize = 56;

/// Decode target for a map thumbnail: twice the tile edge so it stays sharp
/// on 2x displays and still two orders of magnitude cheaper than the
/// original.
const Size _thumbnailTarget = Size(112, 112);

/// One media thumbnail on the map. With [count] it is a cluster's
/// representative tile and carries a count badge.
///
/// Deliberately gesture-free: the map wraps it in the tap handling it needs,
/// and the cluster plugin owns the cluster tap.
class MediaMapMarker extends StatelessWidget {
  const MediaMapMarker({super.key, required this.item, this.count});

  final MediaItem item;

  /// Number of items behind this tile when it stands for a cluster; null
  /// for a single item.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badgeCount = count;

    return SizedBox(
      width: kMediaMapMarkerSize,
      height: kMediaMapMarkerSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: kMediaMapMarkerSize,
            height: kMediaMapMarkerSize,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.surface, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: MediaItemView(
                item: item,
                thumbnail: true,
                targetSize: _thumbnailTarget,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (item.isVideo)
            const Positioned(
              left: 4,
              bottom: 4,
              child: Icon(
                Icons.play_circle_fill,
                size: 16,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
              ),
            ),
          if (badgeCount != null)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                key: const ValueKey('media-map-cluster-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
                child: Text(
                  '$badgeCount',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
