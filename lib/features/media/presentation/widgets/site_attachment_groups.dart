import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/site_attachment_layout.dart';
import 'package:submersion/features/media/presentation/helpers/site_attachment_labels.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_large_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

/// A site's attachments in category groups (issue #1039): a heading per
/// group when anything is categorized, the group's large cards, then its
/// tiles in a grid.
///
/// Every grid and card reports to the one id-based [selection], so a
/// selection can span groups.
class SiteAttachmentGroups extends StatelessWidget {
  const SiteAttachmentGroups({
    super.key,
    required this.layout,
    required this.selection,
    required this.isSelectionMode,
    required this.settings,
    required this.onOpen,
    required this.onEditDetails,
  });

  final SiteAttachmentLayout layout;
  final SelectionController selection;
  final bool isSelectionMode;
  final AppSettings settings;
  final void Function(MediaItem) onOpen;
  final void Function(MediaItem) onEditDetails;

  @override
  Widget build(BuildContext context) {
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
              onEditDetails: () => onEditDetails(item),
            ),
          ),
        );
      }
      if (group.tiles.isNotEmpty) {
        children.add(_tileGrid(context, group));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _tileGrid(BuildContext context, SiteAttachmentGroup group) {
    final tiles = group.tiles;
    final groupIds = {for (final t in tiles) t.id};
    return DragSelectGridView<MediaItem>(
      key: ValueKey('tiles-${group.category?.storageKey ?? 'none'}'),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, item, isSelected) => MediaThumbnailTile(
        item: item,
        settings: settings,
        isSelectionMode: isSelectionMode,
        isSelected: isSelected,
        semanticsLabel: context.l10n.media_diveMediaSection_thumbnailLabel,
      ),
    );
  }
}
