import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/helpers/elapsed_time_format.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_scroll_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/media_status_badge.dart';
import 'package:submersion/features/media/presentation/widgets/media_tile_markers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Below this width a tile drops its markers and duration, which would
/// otherwise crowd the badge and the selection check (issue #4738).
const double kMediaTileDetailWidth = 64;

/// Each entry's shape as the justified grid lays it out: learned, stored or
/// fallback, then clamped (issue #4738).
List<double> mediaLibraryRatios(
  List<MediaLibraryEntry> entries,
  Map<String, LearnedAspect> learned,
) => mediaLayoutRatios(entries.map((entry) => entry.item), learned);

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
    this.onImageSize,
  });

  final MediaLibraryEntry entry;
  final bool selected;
  final VoidCallback onTap;

  /// The size the thumbnail is resolved and decoded at. Larger tiles ask
  /// for more (issue #3297), up to the cap in [mediaThumbnailDecodeTarget],
  /// so a large thumbnail is not a 200px image stretched.
  final Size targetSize;

  /// Called with the thumbnail's decoded size, which is how the library
  /// learns a photo's displayed shape (issue #4738).
  final ValueChanged<Size>? onImageSize;

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
      await showMediaInfoSheet(
        context,
        entry.item,
        // A photo is changed only in the viewer, unlocked (issue #4527).
        readOnly: true,
      );
    }
  }
  // coverage:ignore-end

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = entry.item.mediaType == MediaType.video
        ? entry.item.durationSeconds
        : null;
    return GestureDetector(
      onTap: onTap,
      onSecondaryTapDown: (details) => _showContextMenu(context, details),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final roomy = constraints.maxWidth >= kMediaTileDetailWidth;
          return Stack(
            fit: StackFit.expand,
            children: [
              MediaItemView(
                item: entry.item,
                thumbnail: true,
                targetSize: targetSize,
                fit: BoxFit.cover,
                onImageSize: onImageSize,
              ),
              if (isSelectionMode && !selected)
                Container(color: Colors.black.withValues(alpha: 0.3)),
              // Top-left: the top-right corner belongs to the selection check.
              Positioned(
                top: 4,
                left: 4,
                child: MediaStatusBadge(item: entry.item),
              ),
              // Bottom-left: free on a library tile, and away from both badges
              // above (issue #4218).
              if (roomy)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: MediaTileMarkers(entry: entry),
                ),
              if (roomy && duration != null)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: _DurationChip(seconds: duration),
                ),
              if (selected) ...[
                Container(color: colorScheme.primary.withValues(alpha: 0.3)),
                // On its own disc, as the dive and site media grids draw it: a
                // bare white glyph was lost on bright photos and placeholders.
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A video's length, bottom right of its tile, styled like the markers
/// opposite it (issue #4738).
class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('media-tile-duration'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        formatClipDuration(seconds),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Flat justified thumbnail grid over library entries with near-end
/// load-more (issue #4738).
///
/// Purely presentational: paging state lives in the library notifier; this
/// widget only reports "the user is close to the bottom" via [onLoadMore].
class MediaLibraryGrid extends ConsumerWidget {
  const MediaLibraryGrid({
    super.key,
    required this.entries,
    required this.hasMore,
    required this.onLoadMore,
    required this.onTileTap,
    required this.rowHeight,
    this.selectedIds = const {},
    this.isSelectionMode = false,
  });

  final List<MediaLibraryEntry> entries;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final void Function(MediaLibraryEntry entry, int index) onTileTap;

  /// The height rows are packed at, from the size slider (issues #3297,
  /// #4738).
  final double rowHeight;

  /// Ids rendered with the selection overlay.
  final Set<String> selectedIds;

  /// Whether the surface is in multi-select, which can be true with nothing
  /// checked.
  final bool isSelectionMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The first layout waits for the learned shapes, so a returning diver
    // never sees rotated photos jump into place.
    final learned = ref.watch(mediaLearnedAspectsProvider).value;
    if (learned == null) return const SizedBox.shrink();
    final section = JustifiedSection(
      headerExtents: const [],
      ratios: mediaLibraryRatios(entries, learned),
    );
    return JustifiedMediaScrollView(
      sectionsFor: (_) => [section],
      rowHeight: rowHeight,
      hasMore: hasMore,
      onLoadMore: onLoadMore,
      padding: const EdgeInsets.symmetric(vertical: 4),
      cellBuilder: (context, cell) {
        final entry = entries[cell.tile];
        return MediaLibraryTile(
          entry: entry,
          selected: selectedIds.contains(entry.item.id),
          isSelectionMode: isSelectionMode,
          targetSize: mediaThumbnailDecodeTarget(cell.size),
          onImageSize: (size) => ref
              .read(mediaLearnedAspectsProvider.notifier)
              .report(entry.item, size),
          onTap: () => onTileTap(entry, cell.tile),
        );
      },
    );
  }
}
