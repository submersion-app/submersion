import 'package:flutter/material.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_dive_photos_list.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_dive_photos_page.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_photo_link_sheet.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';

/// The gear page's In dive photos card (issue #5046): dive photos and videos
/// linked to the item as showing it. Apart from the Photos card, so a dive
/// shot never mixes with the item's reference photos or becomes its cover.
///
/// Shows two rows; Show all opens the rest. While the card is open
/// ([editing]), Link photos and each photo's unlink are held in the item's
/// sitting until Save; a closed card shows what a sitting holds ([shown]).
class EquipmentDivePhotosSection extends ConsumerWidget {
  const EquipmentDivePhotosSection({
    super.key,
    required this.equipment,
    this.editing,
    this.shown,
  });

  final EquipmentItem equipment;

  /// The open card's sitting, where links are changed.
  final EditSession<EquipmentItem>? editing;

  /// The sitting whose links a closed card shows.
  final EditSession<EquipmentItem>? shown;

  /// Tiles on the card: two rows of four.
  static const maxTiles = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = editing ?? shown;
    if (session == null || session.isDisposed) {
      return _card(context, ref, null);
    }
    return ListenableBuilder(
      listenable: gearItemDivePhotosList.changes(session),
      builder: (context, _) => _card(context, ref, session),
    );
  }

  Widget _card(
    BuildContext context,
    WidgetRef ref,
    EditSession<EquipmentItem>? session,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stored = ref.watch(linkedMediaForEquipmentProvider(equipment.id));
    final visibleIds = <String>{
      for (final m in stored.value ?? const <MediaItem>[]) m.id,
    };
    final held = session == null
        ? null
        : gearItemDivePhotosShown(session, visibleIds: visibleIds);
    final photosAsync = held != null
        ? AsyncValue<List<MediaItem>>.data(held)
        : stored;
    final canAct =
        editing != null && ref.watch(deviceCapabilitiesProvider).mediaAttach;
    final photos = photosAsync.value ?? const <MediaItem>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_camera_back_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.equipment_divePhotos_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (photos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${photos.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                RecordCardPencil(cardTitle: l10n.equipment_divePhotos_title),
                if (canAct)
                  IconButton(
                    key: const ValueKey('equipment_divePhotos_link'),
                    icon: Icon(Icons.add_link, color: colorScheme.primary),
                    tooltip: l10n.equipment_divePhotos_link,
                    onPressed: () => _link(context, photos),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            photosAsync.when(
              data: (photos) => photos.isEmpty
                  ? MediaEmptyState(
                      icon: Icons.photo_camera_back_outlined,
                      message: l10n.equipment_divePhotos_empty,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Grid(
                          photos: photos.take(maxTiles).toList(),
                          onTap: (item) =>
                              openMediaViewer(context, photos, item.id),
                          onUnlink: canAct ? _unlink : null,
                        ),
                        if (photos.length > maxTiles)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const ValueKey('equipment_divePhotos_all'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EquipmentDivePhotosPage(
                                    itemName: equipment.name,
                                    photos: photos,
                                  ),
                                ),
                              ),
                              child: Text(
                                l10n.equipment_divePhotos_showAll(
                                  photos.length,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => Text(
                l10n.media_diveMediaSection_errorLoading,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The sitting's list with [keep] in place of the photos the card shows:
  /// the links the diver cannot see stay as they are.
  void _replaceShown(List<MediaItem> shownNow, List<MediaItem> keep) {
    final session = editing;
    if (session == null || session.isDisposed || session.isFrozen) return;
    final current = gearItemDivePhotosList.current(session);
    if (current == null) return;
    final shownIds = {for (final m in shownNow) m.id};
    gearItemDivePhotosList.set(session, [
      for (final m in current)
        if (!shownIds.contains(m.id)) m,
      ...keep,
    ]);
  }

  void _unlink(MediaItem item) {
    final session = editing;
    if (session == null || session.isDisposed || session.isFrozen) return;
    final current = gearItemDivePhotosList.current(session);
    if (current == null) return;
    gearItemDivePhotosList.set(session, [
      for (final m in current)
        if (m.id != item.id) m,
    ]);
  }

  Future<void> _link(BuildContext context, List<MediaItem> shownNow) async {
    final session = editing;
    if (session == null) return;
    // The list must be read before it can be changed.
    await gearItemDivePhotosList.currentOrRead(session);
    if (!context.mounted) return;
    final picked = await showGearPhotoLinkSheet(
      context,
      item: equipment,
      linked: shownNow,
    );
    if (picked == null) return;
    _replaceShown(shownNow, picked);
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({required this.photos, required this.onTap, this.onUnlink});

  final List<MediaItem> photos;
  final void Function(MediaItem) onTap;
  final void Function(MediaItem)? onUnlink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(unitFormatterProvider).settings;
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final item = photos[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => onTap(item),
              child: MediaThumbnailTile(
                item: item,
                settings: settings,
                isSelectionMode: false,
                isSelected: false,
                semanticsLabel: l10n.equipment_photos_photoLabel,
              ),
            ),
            if (onUnlink case final unlink?)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton.filledTonal(
                  key: ValueKey('equipment_divePhotos_unlink_${item.id}'),
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: l10n.equipment_divePhotos_unlink,
                  icon: Icon(Icons.link_off, color: colorScheme.error),
                  onPressed: () => unlink(item),
                ),
              ),
          ],
        );
      },
    );
  }
}
