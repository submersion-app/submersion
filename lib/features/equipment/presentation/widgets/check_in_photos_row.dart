import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/presentation/editing/gear_item_check_ins_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_photo_import_helper.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_photo_remove_dialog.dart';
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
///
/// In an item page's sitting (issue #4527, phase 3) it writes nothing: the
/// photos added ([heldAdded]) and removed ([heldRemoved]) are handed to
/// [onHeldChanged] and written with the check-in at Save; a remove asks
/// nothing, as Cancel brings it back.
class CheckInPhotosRow extends ConsumerWidget {
  const CheckInPhotosRow({
    super.key,
    required this.equipmentId,
    required this.observationId,
    this.heldAdded = const [],
    this.elsewhere = noPhotosHeldElsewhere,
    this.heldRemoved = const {},
    this.onHeldChanged,
  });

  final String equipmentId;
  final String observationId;
  final List<HeldMediaAdd> heldAdded;

  /// The photos the sitting holds outside this check-in: a pick of one it
  /// adds there is left out, as the item has it already; one it unlinks
  /// there may be picked again.
  final PhotosHeldElsewhere elsewhere;
  final Set<String> heldRemoved;
  final void Function(List<HeldMediaAdd> added, Set<String> removed)?
  onHeldChanged;

  /// Takes [mediaId] out in the sitting: one added in it is dropped, a
  /// stored one marked removed.
  void _holdRemove(String mediaId) {
    final added = [
      for (final a in heldAdded)
        if (a.preview.id != mediaId) a,
    ];
    onHeldChanged!(
      added,
      added.length == heldAdded.length
          ? {...heldRemoved, mediaId}
          : heldRemoved,
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) {
    final hold = onHeldChanged;
    if (hold == null) {
      return GearPhotoImportHelper.importPhotos(
        context: context,
        ref: ref,
        equipmentId: equipmentId,
        observationId: observationId,
      );
    }
    return GearPhotoImportHelper.holdPhotos(
      context: context,
      ref: ref,
      equipmentId: equipmentId,
      observationId: observationId,
      ignoringMediaIds: {...heldRemoved, ...elsewhere.unlinked},
      onHold: (adds) => hold(
        withHeldPhotosAdded(heldAdded, adds, heldElsewhere: elsewhere.keys),
        heldRemoved,
      ),
    );
  }

  static const double _thumb = 56;
  static const double _removeTarget = 32;

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String mediaId,
  ) async {
    // The sheet may close while the dialog is up, taking this row's ref.
    if (!await confirmRemoveGearPhotos(context, 1) || !context.mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await ref.read(mediaUnlinkServiceProvider).unlinkFromEquipment([mediaId]);
    } catch (e) {
      // As the Photos card and the Gear gallery do: the photo stays, so
      // say why rather than leaving the tap looking ignored.
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.media_siteMediaSection_unlinkError(e)),
          backgroundColor: errorColor,
        ),
      );
      return;
    }
    ref.invalidate(observationPhotosProvider(observationId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canAttach = ref.watch(deviceCapabilitiesProvider).mediaAttach;
    final settings = ref.watch(unitFormatterProvider).settings;
    final stored =
        ref.watch(observationPhotosProvider(observationId)).value ?? const [];
    // In a sitting: what it removed gone, what it added in.
    final photos = onHeldChanged == null
        ? stored
        : [
            for (final m in stored)
              if (!heldRemoved.contains(m.id)) m,
            for (final a in heldAdded) a.preview,
          ];
    final colorScheme = Theme.of(context).colorScheme;
    // Nothing to show and no way to add: a browser editing a check-in with
    // no photos.
    if (photos.isEmpty && !canAttach) return const SizedBox.shrink();

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
                    // A small corner badge in a larger corner target: easy
                    // to hit (above the WCAG AA 24px minimum) while most of
                    // the tile still opens the photo. Removing asks first,
                    // as everywhere else.
                    if (canAttach)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Tooltip(
                          message: l10n.equipment_photos_remove,
                          child: InkWell(
                            key: ValueKey('remove_checkin_photo_${photo.id}'),
                            customBorder: const CircleBorder(),
                            onTap: onHeldChanged == null
                                ? () => _confirmRemove(context, ref, photo.id)
                                : () => _holdRemove(photo.id),
                            child: SizedBox.square(
                              dimension: _removeTarget,
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Container(
                                    key: ValueKey(
                                      'remove_checkin_badge_${photo.id}',
                                    ),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface.withValues(
                                        alpha: 0.85,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: colorScheme.error,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                  onPressed: () => _add(context, ref),
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
