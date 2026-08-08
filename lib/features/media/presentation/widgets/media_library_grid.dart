import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';

/// One library thumbnail with the shared selection overlay. Used by both the
/// flat grid and the grouped list so the two modes cannot diverge.
class MediaLibraryTile extends StatelessWidget {
  const MediaLibraryTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final MediaLibraryEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaItemView(
            item: entry.item,
            thumbnail: true,
            targetSize: const Size(200, 200),
            fit: BoxFit.cover,
          ),
          if (selected) ...[
            Container(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.check_circle, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

/// Flat thumbnail grid over library entries with near-end load-more.
///
/// Purely presentational: paging state lives in the library notifier; this
/// widget only reports "the user is close to the bottom" via [onLoadMore].
class MediaLibraryGrid extends StatelessWidget {
  const MediaLibraryGrid({
    super.key,
    required this.entries,
    required this.hasMore,
    required this.onLoadMore,
    required this.onTileTap,
    this.selectedIds = const {},
    this.onTileLongPress,
  });

  final List<MediaLibraryEntry> entries;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final void Function(MediaLibraryEntry entry, int index) onTileTap;

  /// Ids rendered with the selection overlay.
  final Set<String> selectedIds;

  /// Long-press hook for entering selection mode.
  final void Function(MediaLibraryEntry entry)? onTileLongPress;

  static const double _loadMoreThreshold = 400;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (hasMore &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - _loadMoreThreshold) {
          onLoadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return MediaLibraryTile(
            entry: entry,
            selected: selectedIds.contains(entry.item.id),
            onTap: () => onTileTap(entry, index),
            onLongPress: onTileLongPress == null
                ? null
                : () => onTileLongPress!(entry),
          );
        },
      ),
    );
  }
}
