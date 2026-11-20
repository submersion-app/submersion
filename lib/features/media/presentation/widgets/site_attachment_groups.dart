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
import 'package:submersion/features/media/presentation/widgets/justified_media_preview.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_large_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

/// The height a group's tile rows aim for (issue #4741).
const double kSiteAttachmentRowHeight = 120;

/// A site's attachments in category groups (issue #1039): a heading per
/// group when anything is categorized, the group's large cards, then its
/// tiles in justified rows that keep each one's shape (issue #4741).
///
/// Every grid and card reports to the one id-based [selection], so a
/// selection can span groups.
class SiteAttachmentGroups extends ConsumerWidget {
  const SiteAttachmentGroups({
    super.key,
    required this.layout,
    required this.selection,
    required this.isSelectionMode,
    required this.settings,
    required this.onOpen,
    this.onEditDetails,
  });

  final SiteAttachmentLayout layout;
  final SelectionController selection;
  final bool isSelectionMode;
  final UnitFormatterSettings settings;
  final void Function(MediaItem) onOpen;

  /// Edit details for one attachment; null offers none, where the
  /// attachment is edited under its own lock (issue #4527, phase 2).
  final void Function(MediaItem)? onEditDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tiles wait for the learned shapes, as the library does, so a photo
    // stored sideways never lays out wide and then jumps.
    final learned = ref.watch(mediaLearnedAspectsProvider).value;
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
      for (final item in group.large) {
        children.add(
          // Keyed on the Column's direct child, where Flutter matches keys, so
          // a recategorized card keeps its element instead of inheriting a
          // neighbour's.
          Padding(
            key: ValueKey('large-${item.id}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: SiteAttachmentLargeCard(
              item: item,
              isSelectionMode: isSelectionMode,
              isSelected: selection.value.isChecked(item.id),
              onTap: isSelectionMode
                  ? () => selection.toggle(item.id)
                  : () => onOpen(item),
              onEditDetails: switch (onEditDetails) {
                final edit? => () => edit(item),
                null => null,
              },
            ),
          ),
        );
      }
      if (group.tiles.isNotEmpty && learned != null) {
        children.add(_tileGrid(context, ref, group, learned));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _tileGrid(
    BuildContext context,
    WidgetRef ref,
    SiteAttachmentGroup group,
    Map<String, LearnedAspect> learned,
  ) {
    final tiles = group.tiles;
    final groupIds = {for (final t in tiles) t.id};
    final aspects = ref.read(mediaLearnedAspectsProvider.notifier);
    return _JustifiedTileTable(
      key: ValueKey('tiles-${group.category?.storageKey ?? 'none'}'),
      ratios: mediaLayoutRatios(tiles, learned),
      builder: (context, table) =>
          _dragSelectGrid(context, tiles, groupIds, table, aspects),
    );
  }

  Widget _dragSelectGrid(
    BuildContext context,
    List<MediaItem> tiles,
    Set<String> groupIds,
    JustifiedMediaTable table,
    MediaLearnedAspectsNotifier aspects,
  ) {
    return DragSelectGridView<MediaItem>(
      items: tiles,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      startInSelectionMode: isSelectionMode,
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
      onItemTap: (index) => onOpen(tiles[index]),
      gridDelegate: JustifiedMediaGridDelegate(table),
      // A grid child gets its cell's size as tight constraints, so the tile
      // decodes at what it shows.
      itemBuilder: (context, item, isSelected) => LayoutBuilder(
        builder: (context, constraints) => MediaThumbnailTile(
          item: item,
          settings: settings,
          isSelectionMode: isSelectionMode,
          isSelected: isSelected,
          semanticsLabel: context.l10n.media_diveMediaSection_thumbnailLabel,
          targetSize: mediaThumbnailDecodeTarget(constraints.biggest),
          onImageSize: (size) => aspects.report(item, size),
        ),
      ),
    );
  }
}

/// One group's tiles packed into justified rows across the width it is
/// given (issue #4741), handed to [builder] as a table for the grid's
/// delegate.
///
/// The table is kept while the shapes and the width are unchanged: the
/// delegate lays the grid out again on a new table, and every check in
/// Select mode rebuilds every group.
class _JustifiedTileTable extends StatefulWidget {
  const _JustifiedTileTable({
    super.key,
    required this.ratios,
    required this.builder,
  });

  final List<double> ratios;
  final Widget Function(BuildContext context, JustifiedMediaTable table)
  builder;

  @override
  State<_JustifiedTileTable> createState() => _JustifiedTileTableState();
}

class _JustifiedTileTableState extends State<_JustifiedTileTable> {
  JustifiedSection? _section;
  JustifiedMediaTable? _table;

  JustifiedMediaTable _tableFor(double width) {
    final section = JustifiedSection(
      headerExtents: const [],
      ratios: widget.ratios,
    );
    final kept = _table;
    if (kept != null && section == _section && kept.paneWidth == width) {
      return kept;
    }
    _section = section;
    return _table = JustifiedMediaTable.build(
      sections: [section],
      paneWidth: width,
      targetHeight: kSiteAttachmentRowHeight,
      gap: kJustifiedPreviewGap,
      inset: 0,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        widget.builder(context, _tableFor(constraints.maxWidth)),
  );
}
