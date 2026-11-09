import 'package:flutter/material.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_photo_import_helper.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The check-in editor's photos (issue #3355): what backs up this finding.
///
/// [observationId] is the check-in's id, chosen when the editor opened so a
/// photo added before Save can already name it. Adding and removing take
/// effect at once, as everywhere else media is linked; the sheet unlinks
/// what a new check-in gathered if it is never saved.
class CheckInPhotosRow extends ConsumerWidget {
  const CheckInPhotosRow({
    super.key,
    required this.equipmentId,
    required this.observationId,
  });

  final String equipmentId;
  final String observationId;

  static const double _thumb = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canAttach = ref.watch(deviceCapabilitiesProvider).mediaAttach;
    final settings = ref.watch(unitFormatterProvider).settings;
    final photos =
        ref.watch(observationPhotosProvider(observationId)).value ?? const [];
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.equipment_photos_checkInPhotos,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final photo in photos)
              SizedBox.square(
                dimension: _thumb,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () => openMediaViewer(context, photos, photo.id),
                      child: MediaThumbnailTile(
                        item: photo,
                        settings: settings,
                        isSelectionMode: false,
                        isSelected: false,
                        semanticsLabel: l10n.equipment_photos_photoLabel,
                      ),
                    ),
                    if (canAttach)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: IconButton(
                          key: ValueKey('remove_checkin_photo_${photo.id}'),
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          tooltip: l10n.equipment_photos_remove,
                          icon: Icon(Icons.cancel, color: colorScheme.error),
                          onPressed: () async {
                            await ref
                                .read(mediaUnlinkServiceProvider)
                                .unlinkFromEquipment([photo.id]);
                            ref.invalidate(
                              observationPhotosProvider(observationId),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            if (canAttach)
              SizedBox.square(
                dimension: _thumb,
                child: OutlinedButton(
                  key: const ValueKey('add_checkin_photo'),
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => GearPhotoImportHelper.importPhotos(
                    context: context,
                    ref: ref,
                    equipmentId: equipmentId,
                    observationId: observationId,
                  ),
                  child: Tooltip(
                    message: l10n.equipment_photos_add,
                    child: const Icon(Icons.add_a_photo_outlined),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
