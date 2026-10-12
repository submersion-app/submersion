import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/media_status_badge.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_wheel_zoom.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_zoom_anchor.dart';
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
    this.targetSize = const Size(200, 200),
  });

  final MediaLibraryEntry entry;
  final bool selected;
  final VoidCallback onTap;

  /// The size the thumbnail is resolved and decoded at. Larger tiles ask
  /// for more (issue #3297), up to the cap in [mediaThumbnailDecodeTarget],
  /// so a large thumbnail is not a 200px image stretched.
  final Size targetSize;

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
            targetSize: targetSize,
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
/// Its one piece of state is the scroll position, so a wheel zoom can keep
/// the thumbnail under the cursor where it is.
class MediaLibraryGrid extends StatefulWidget {
  const MediaLibraryGrid({
    super.key,
    required this.entries,
    required this.hasMore,
    required this.onLoadMore,
    required this.onTileTap,
    required this.columns,
    this.targetSize = kDefaultThumbnailTarget,
    this.selectedIds = const {},
    this.isSelectionMode = false,
  });

  final List<MediaLibraryEntry> entries;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final void Function(MediaLibraryEntry entry, int index) onTileTap;

  /// How many thumbnails go across, from the size slider (issue #3297).
  final int columns;

  /// The size to decode thumbnails at, from the pane's width and [columns]
  /// (see [mediaThumbnailDecodeTarget]).
  final Size targetSize;

  /// Ids rendered with the selection overlay.
  final Set<String> selectedIds;

  /// Whether the surface is in multi-select, which can be true with nothing
  /// checked.
  final bool isSelectionMode;

  static const double _loadMoreThreshold = 400;

  @override
  State<MediaLibraryGrid> createState() => _MediaLibraryGridState();
}

class _MediaLibraryGridState extends State<MediaLibraryGrid> {
  /// The grid's scroll position, picked up from a tile's context. Not a
  /// ScrollController: giving the grid one would stop it being the page's
  /// primary scroll view.
  ScrollPosition? _position;

  @override
  void didUpdateWidget(MediaLibraryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columns == widget.columns) return;
    // A wheel zoom: move the offset now, before the new layout, so the
    // thumbnail under the cursor is drawn on the same line (issue #3297).
    final anchor = MediaThumbnailZoomAnchorScope.takeFrom(context);
    final position = _position;
    if (anchor == null || position == null || !position.hasPixels) return;
    position.correctPixels(
      anchor.scrollOffsetFor(
        pixels: position.pixels,
        oldColumns: oldWidget.columns,
        newColumns: widget.columns,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (widget.hasMore &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent -
                    MediaLibraryGrid._loadMoreThreshold) {
          widget.onLoadMore();
        }
        return false;
      },
      child: GridView.builder(
        // Lets Ctrl + wheel resize instead of scroll (issue #3297).
        physics: const MediaThumbnailWheelZoomPhysics(),
        padding: const EdgeInsets.all(4),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.columns,
          mainAxisSpacing: kMediaThumbnailGap,
          crossAxisSpacing: kMediaThumbnailGap,
        ),
        itemCount: widget.entries.length,
        itemBuilder: (context, index) {
          _position = Scrollable.maybeOf(context)?.position;
          final entry = widget.entries[index];
          return MetaData(
            metaData: MediaThumbnailSlot(row: 0, index: index),
            behavior: HitTestBehavior.opaque,
            child: MediaLibraryTile(
              entry: entry,
              selected: widget.selectedIds.contains(entry.item.id),
              isSelectionMode: widget.isSelectionMode,
              targetSize: widget.targetSize,
              onTap: () => widget.onTileTap(entry, index),
            ),
          );
        },
      ),
    );
  }
}
