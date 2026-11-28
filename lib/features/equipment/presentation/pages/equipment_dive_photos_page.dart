import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every dive photo linked to a gear item (issue #5046), past the two rows
/// its In dive photos card shows. Read-only: a photo opens the viewer, and
/// links are changed on the card or the photo itself.
///
/// Holds only the photos' [ids] and reads their rows a page at a time as
/// the grid reaches them, so an item linked to thousands opens at once.
class EquipmentDivePhotosPage extends ConsumerWidget {
  const EquipmentDivePhotosPage({
    super.key,
    required this.itemName,
    required this.ids,
  });

  final String itemName;
  final List<String> ids;

  /// Photos read at a time.
  static const pageSize = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.equipment_divePhotos_title),
            Text(
              itemName,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: ids.length,
        itemBuilder: (context, index) => _Tile(
          id: ids[index],
          pageIds: ids.sublist(
            index - index % pageSize,
            (index - index % pageSize + pageSize).clamp(0, ids.length),
          ),
        ),
      ),
    );
  }
}

/// One photo, read with the rest of its page ([pageIds]).
class _Tile extends ConsumerWidget {
  const _Tile({required this.id, required this.pageIds});

  final String id;
  final List<String> pageIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page =
        ref.watch(mediaInOrderProvider(mediaPageKey(pageIds))).value ??
        const <MediaItem>[];
    final item = page.where((m) => m.id == id).firstOrNull;
    if (item == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }
    return GestureDetector(
      onTap: () => openMediaViewer(context, page, item.id),
      child: MediaThumbnailTile(
        item: item,
        settings: ref.watch(unitFormatterProvider).settings,
        isSelectionMode: false,
        isSelected: false,
        semanticsLabel: context.l10n.equipment_photos_photoLabel,
      ),
    );
  }
}
