import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The media map's place strip: the items stacked at one point, as a
/// horizontal row of thumbnails under a place title.
///
/// An in-map overlay rather than a modal sheet, so the map stays pannable
/// underneath and the panel behaves the same on a phone and on a wide
/// desktop window, the way `MapInfoCard` sits on the other maps. The map
/// owns the open/closed state and positions this widget.
class MediaPlaceStrip extends StatelessWidget {
  const MediaPlaceStrip({
    super.key,
    required this.title,
    required this.points,
    required this.onClose,
    required this.onItemTap,
  });

  /// The place label, or formatted coordinates when no site is known.
  final String title;

  /// The stacked items, in date order, oldest first.
  final List<MediaMapPoint> points;

  final VoidCallback onClose;
  final void Function(MediaMapPoint point) onItemTap;

  static const double _tileEdge = 96;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.media_map_closeStrip,
                  onPressed: onClose,
                ),
              ],
            ),
            Text(
              l10n.media_map_placeItemCount(points.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _tileEdge,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: points.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final point = points[index];
                  return Semantics(
                    button: true,
                    label: l10n.media_map_markerSemantics,
                    child: GestureDetector(
                      key: ValueKey('media-place-strip-tile-${point.item.id}'),
                      onTap: () => onItemTap(point),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: _tileEdge,
                          height: _tileEdge,
                          child: MediaItemView(
                            item: point.item,
                            thumbnail: true,
                            targetSize: const Size(192, 192),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
