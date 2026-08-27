import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Helper for importing photos as direct site attachments.
///
/// Opens the photo picker without a dive time window (a site has no entry/
/// exit times), imports the selection, and refreshes the site providers.
class SiteMediaImportHelper {
  /// Opens the photo picker and imports the selection for [siteId].
  ///
  /// Returns true if anything was imported.
  static Future<bool> importPhotosForSite({
    required BuildContext context,
    required WidgetRef ref,
    required String siteId,
  }) async {
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final alreadyLinkedIds = await mediaRepo.getLinkedAssetIdsForSite(siteId);
    if (!context.mounted) return false;

    // Sites have no dive window: open the picker over all time. buffer is
    // zeroed so showPhotoPicker does not widen the range further.
    //
    // The target is what makes the Files and URL tabs usable here. Those
    // tabs persist rows themselves instead of returning a selection, and
    // without it they fall back to matching against dives, which for a site
    // meant no commit button at all (issue #1098). They also do not pop with
    // a result, so `linkSelectedAssets` below sees null and no-ops for them;
    // that is correct, they have already written their rows, and
    // mediaForSiteProvider picks the change up through watchMediaChanges.
    // coverage:ignore-start
    // showPhotoPicker drives a full-screen page tied to photo_manager + the
    // platform photo library; not unit-testable from flutter_test.
    final selectedAssets = await showPhotoPicker(
      context: context,
      diveStartTime: DateTime.fromMillisecondsSinceEpoch(0),
      diveEndTime: DateTime.now().add(const Duration(days: 1)),
      buffer: Duration.zero,
      alreadyLinkedIds: alreadyLinkedIds,
      target: SiteAttachTarget(siteId),
    );
    // coverage:ignore-end
    if (!context.mounted) return false;
    return linkSelectedAssets(
      context: context,
      ref: ref,
      siteId: siteId,
      selectedAssets: selectedAssets,
    );
  }

  /// Persists [selectedAssets] against [siteId], refreshes the site
  /// providers, and reports the outcome in a SnackBar.
  ///
  /// Split out from [importPhotosForSite] because everything above it is
  /// the photo picker, which cannot run under flutter_test; this half is
  /// the part with branches worth testing.
  static Future<bool> linkSelectedAssets({
    required BuildContext context,
    required WidgetRef ref,
    required String siteId,
    required List<AssetInfo>? selectedAssets,
  }) async {
    if (selectedAssets == null || selectedAssets.isEmpty) return false;

    try {
      final importService = ref.read(mediaImportServiceProvider);
      final result = await importService.importPhotosForSite(
        selectedAssets: selectedAssets,
        siteId: siteId,
      );

      ref.invalidate(mediaForSiteProvider(siteId));
      ref.invalidate(mediaCountForSiteProvider(siteId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.media_import_importedPhotos(result.imported.length),
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
