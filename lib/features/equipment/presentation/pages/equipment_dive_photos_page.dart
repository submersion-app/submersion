import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every dive photo linked to a gear item (issue #5046), past the two rows
/// its In dive photos card shows. Read-only: a photo opens the viewer, and
/// links are changed on the card or the photo itself.
class EquipmentDivePhotosPage extends ConsumerWidget {
  const EquipmentDivePhotosPage({
    super.key,
    required this.itemName,
    required this.photos,
  });

  final String itemName;
  final List<MediaItem> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(unitFormatterProvider).settings;
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
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final item = photos[index];
          return GestureDetector(
            onTap: () => openMediaViewer(context, photos, item.id),
            child: MediaThumbnailTile(
              item: item,
              settings: settings,
              isSelectionMode: false,
              isSelected: false,
              semanticsLabel: l10n.equipment_photos_photoLabel,
            ),
          );
        },
      ),
    );
  }
}
