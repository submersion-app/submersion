import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Adds photos to a gear item (issue #3355), and to one of its check-ins
/// when [observationId] is given. Mirrors `SiteMediaImportHelper`: the
/// picker opens over all time (a gear item has no dive window), and the
/// Files and URL tabs write their own rows through the
/// [EquipmentAttachTarget].
class GearPhotoImportHelper {
  /// Opens the photo picker and links the selection. Returns true if
  /// anything was linked.
  static Future<bool> importPhotos({
    required BuildContext context,
    required WidgetRef ref,
    required String equipmentId,
    String? observationId,
  }) async {
    // As this device knows them: a row linked on another device carries that
    // device's asset id (#885).
    final alreadyLinkedIds = await ref
        .read(linkedGalleryAssetsProvider)
        .idsOnThisDevice(
          await ref
              .read(gearPhotoRepositoryProvider)
              .galleryLinksFor(equipmentId),
        );
    if (!context.mounted) return false;
    // coverage:ignore-start
    // showPhotoPicker drives a full-screen page tied to photo_manager and the
    // platform photo library; not unit-testable from flutter_test.
    final selectedAssets = await showPhotoPicker(
      context: context,
      diveStartTime: DateTime.fromMillisecondsSinceEpoch(0),
      diveEndTime: DateTime.now().add(const Duration(days: 1)),
      buffer: Duration.zero,
      alreadyLinkedIds: alreadyLinkedIds,
      target: EquipmentAttachTarget(equipmentId, observationId: observationId),
    );
    // coverage:ignore-end
    if (!context.mounted) return false;
    return linkSelectedAssets(
      context: context,
      ref: ref,
      equipmentId: equipmentId,
      observationId: observationId,
      selectedAssets: selectedAssets,
    );
  }

  /// Links [selectedAssets] to the item, refreshes the gear photo providers
  /// and reports the outcome in a SnackBar. Split from [importPhotos]
  /// because the picker cannot run under flutter_test.
  static Future<bool> linkSelectedAssets({
    required BuildContext context,
    required WidgetRef ref,
    required String equipmentId,
    String? observationId,
    required List<AssetInfo>? selectedAssets,
  }) async {
    if (selectedAssets == null || selectedAssets.isEmpty) return false;
    try {
      final result = await ref
          .read(mediaImportServiceProvider)
          .importPhotosForEquipment(
            selectedAssets: selectedAssets,
            equipmentId: equipmentId,
            observationId: observationId,
          );
      ref.invalidate(identificationPhotosProvider(equipmentId));
      ref.invalidate(checkInPhotosProvider(equipmentId));
      if (observationId != null) {
        ref.invalidate(observationPhotosProvider(observationId));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Re-picked photos already on the item are skipped; say so
            // rather than reporting a bare "0 imported".
            content: Text(
              result.skippedDuplicates > 0
                  ? context.l10n.media_import_importedAndSkipped(
                      result.imported.length,
                      result.skippedDuplicates,
                    )
                  : context.l10n.media_import_importedPhotos(
                      result.imported.length,
                    ),
            ),
          ),
        );
      }
      return result.imported.isNotEmpty;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.media_import_failedToImportError(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return false;
    }
  }
}
