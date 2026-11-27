import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter_settings.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/site_attachment_layout.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';
import 'package:submersion/features/media/presentation/helpers/site_attachment_labels.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/justified_span_packer.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

/// The height a group's tile rows aim for (issue #4741).
const double kSiteAttachmentRowHeight = 120;

/// The space between a group's tiles, across and down (issue #4741).
const double kSiteAttachmentGap = 4;

/// A site's attachments in category groups (issue #1039): a heading per
/// group when anything is categorized, then its items in justified rows that
/// keep each one's shape (issue #4741). A Large item spans two rows at the
/// start of its group, with tiles beside it (issue #4786).
///
/// Every grid reports to the one id-based [selection], so a selection can
/// span groups. An item's details are edited through Select.
class SiteAttachmentGroups extends ConsumerWidget {
  const SiteAttachmentGroups({
    super.key,
    required this.layout,
    required this.selection,
    required this.isSelectionMode,
    required this.settings,
    required this.onOpen,
  });

  final SiteAttachmentLayout layout;
  final SelectionController selection;
  final bool isSelectionMode;
  final UnitFormatterSettings settings;
  final void Function(MediaItem) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The tiles wait for the shapes the library has learned from decoded
    // thumbnails, as the library does, so a photo stored sideways never
    // lays out wide and then jumps. A cache that cannot be read loads as
    // empty, so this never waits for good. Read only when there are items.
    final learned = layout.groups.isEmpty
        ? null
        : ref.watch(mediaLearnedAspectsProvider).value;
    final children = <Widget>[];
    for (final group in layout.groups) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 16));
      if (layout.showHeadings) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.l10n.media_siteAttachment_groupHeading(
                group.category.label(context.l10n),
                group.large.length + group.tiles.length,
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        );
      }
      if (learned != null) {
        children.add(
          _TileGrid(
            key: ValueKey('tiles-${group.category?.storageKey ?? 'none'}'),
            large: group.large,
            tiles: group.tiles,
            largeRatios: mediaLayoutRatios(group.large, learned),
            tileRatios: mediaLayoutRatios(group.tiles, learned),
            selection: selection,
            isSelectionMode: isSelectionMode,
            settings: settings,
            onOpen: onOpen,
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// A group's cells in the order its grid builds them, and where each goes.
/// Kept by shape alone, so the items are looked up from the cells on every
/// build: an item swapped for another of the same shape is never stale.
typedef _GroupLayout = ({
  List<JustifiedSpanCell> cells,
  JustifiedMediaTable table,
});

/// One group's items in justified rows, its Large ones spanning two, in a
/// drag-select grid that reports to the shared [selection].
class _TileGrid extends ConsumerStatefulWidget {
  const _TileGrid({
    super.key,
    required this.large,
    required this.tiles,
    required this.largeRatios,
    required this.tileRatios,
    required this.selection,
    required this.isSelectionMode,
    required this.settings,
    required this.onOpen,
  });

  final List<MediaItem> large;
  final List<MediaItem> tiles;

  /// Each item's shape, as [mediaLayoutRatios] gives it.
  final List<double> largeRatios;
  final List<double> tileRatios;
  final SelectionController selection;
  final bool isSelectionMode;
  final UnitFormatterSettings settings;
  final void Function(MediaItem) onOpen;

  @override
  ConsumerState<_TileGrid> createState() => _TileGridState();
}

class _TileGridState extends ConsumerState<_TileGrid> {
  /// The last layout, kept while the width and the tiles' shapes stay the
  /// same, so the grid delegate (which compares tables by identity) does not
  /// lay the grid out again on every rebuild: every check in Select mode
  /// rebuilds every group.
  ({
    List<double> largeRatios,
    List<double> tileRatios,
    double width,
    _GroupLayout layout,
  })?
  _layout;

  /// The group's cells in reading order: the order the grid builds its items
  /// in, which puts each Large item before the tiles beside it.
  _GroupLayout _layoutFor(double width) {
    final largeRatios = widget.largeRatios;
    final tileRatios = widget.tileRatios;
    final cached = _layout;
    if (cached != null &&
        cached.width == width &&
        listEquals(cached.largeRatios, largeRatios) &&
        listEquals(cached.tileRatios, tileRatios)) {
      return cached.layout;
    }
    final cells = packJustifiedSpans(
      largeRatios: largeRatios,
      tileRatios: tileRatios,
      paneWidth: width,
      targetHeight: kSiteAttachmentRowHeight,
      gap: kSiteAttachmentGap,
      minTileWidth: kMediaThumbnailMinTileWidth,
    );
    final layout = (
      cells: cells,
      table: JustifiedMediaTable.placed(
        rects: [for (final c in cells) c.rect],
        ratios: [
          for (final c in cells)
            c.isLarge ? largeRatios[c.index] : tileRatios[c.index],
        ],
        paneWidth: width,
        targetHeight: kSiteAttachmentRowHeight,
      ),
    );
    _layout = (
      largeRatios: largeRatios,
      tileRatios: tileRatios,
      width: width,
      layout: layout,
    );
    return layout;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _grid(context, _layoutFor(constraints.maxWidth)),
    );
  }

  Widget _grid(BuildContext context, _GroupLayout layout) {
    final tiles = [
      for (final c in layout.cells)
        c.isLarge ? widget.large[c.index] : widget.tiles[c.index],
    ];
    final table = layout.table;
    final selection = widget.selection;
    final groupIds = {for (final t in tiles) t.id};
    final largeIds = {for (final m in widget.large) m.id};
    final indexById = {for (var i = 0; i < tiles.length; i++) tiles[i].id: i};
    return DragSelectGridView<MediaItem>(
      items: tiles,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // The page owns the safe-area insets; a grid with no padding would
      // add them again inside every group.
      padding: EdgeInsets.zero,
      startInSelectionMode: widget.isSelectionMode,
      initialSelection: {
        for (var i = 0; i < tiles.length; i++)
          if (selection.value.isChecked(tiles[i].id)) i,
      },
      // The controller owns the mode. Letting the grid also decide had the
      // two fight: its exit callback cleared the controller and the
      // selection callback immediately reactivated it.
      exitOnEmptySelection: false,
      onSelectionChanged: (indices) {
        // The grid reports its whole selection, but only for its own group,
        // so keep every other group's checks and replace this group's. Not
        // selectAll: that declares the mode explicit, which would launder a
        // grid gesture into a deliberate entry.
        final picked = [
          for (final i in indices)
            if (i >= 0 && i < tiles.length) tiles[i].id,
        ];
        selection.replaceChecked([
          for (final id in selection.value.checkedIds)
            if (!groupIds.contains(id)) id,
          ...picked,
        ]);
      },
      // Entry and exit both travel through onSelectionChanged above; the
      // grid follows the controller back out via startInSelectionMode.
      onSelectionModeChanged: (_) {},
      onItemTap: (index) => widget.onOpen(tiles[index]),
      gridDelegate: JustifiedMediaGridDelegate(table),
      itemBuilder: (context, item, isSelected) => MediaThumbnailTile(
        item: item,
        settings: widget.settings,
        isSelectionMode: widget.isSelectionMode,
        isSelected: isSelected,
        large: largeIds.contains(item.id),
        semanticsLabel: context.l10n.media_diveMediaSection_thumbnailLabel,
        targetSize: mediaThumbnailDecodeTarget(
          table.rectOf(indexById[item.id]!).size,
        ),
        // Teaches the library a photo's displayed shape, which lays this
        // group out again too.
        onImageSize: (size) =>
            ref.read(mediaLearnedAspectsProvider.notifier).report(item, size),
      ),
    );
  }
}
