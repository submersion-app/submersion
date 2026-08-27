import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/media_status_badge.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One library thumbnail with the shared selection overlay. Used by both the
/// flat grid and the grouped list so the two modes cannot diverge.
class MediaLibraryTile extends StatelessWidget {
  const MediaLibraryTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    this.isSelectionMode = false,
  });

  final MediaLibraryEntry entry;
  final bool selected;
  final VoidCallback onTap;

  /// Whether the surface is in multi-select. Unselected tiles dim, which is
  /// what makes an explicitly entered mode legible before anything is
  /// checked -- the state the old long-press entry could not even represent.
  final bool isSelectionMode;

  /// Opens the context menu at the pointer.
  ///
  /// Desktop-only in practice: `onSecondaryTapDown` does not fire on a
  /// touchscreen, so mobile reaches the panel through the viewer's info
  /// button instead. Long-press is deliberately unbound here: it enters
  /// selection nowhere in the app, and a hidden gesture is not an
  /// affordance.
  // coverage:ignore-start
  // showMenu at a pointer position is not drivable from flutter_test without
  // a real mouse; the menu's single action is a direct call to the same
  // launcher the badge tap uses, which IS tested.
  Future<void> _showContextMenu(
    BuildContext context,
    TapDownDetails details,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'info',
          child: Text(context.l10n.media_tile_infoMenuItem),
        ),
      ],
    );
    if (selection == 'info' && context.mounted) {
      await showMediaInfoSheet(context, entry.item);
    }
  }
  // coverage:ignore-end

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onSecondaryTapDown: (details) => _showContextMenu(context, details),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaItemView(
            item: entry.item,
            thumbnail: true,
            targetSize: const Size(200, 200),
            fit: BoxFit.cover,
          ),
          if (isSelectionMode && !selected)
            Container(color: Colors.black.withValues(alpha: 0.3)),
          // Top-left: the top-right corner belongs to the selection check.
          Positioned(
            top: 4,
            left: 4,
            child: MediaStatusBadge(item: entry.item),
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
    this.isSelectionMode = false,
  });

  final List<MediaLibraryEntry> entries;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final void Function(MediaLibraryEntry entry, int index) onTileTap;

  /// Ids rendered with the selection overlay.
  final Set<String> selectedIds;

  /// Whether the surface is in multi-select, which can be true with nothing
  /// checked.
  final bool isSelectionMode;

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
            isSelectionMode: isSelectionMode,
            onTap: () => onTileTap(entry, index),
          );
        },
      ),
    );
  }
}
