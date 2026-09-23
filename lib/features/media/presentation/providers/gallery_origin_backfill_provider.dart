import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/gallery_asset_reader.dart';
import 'package:submersion/features/media/data/services/gallery_origin_backfill.dart';
import 'package:submersion/features/media/data/services/photo_picker_service_mobile.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';

/// Runs [GalleryOriginBackfill] once per device, after a successful sync.
///
/// Checks the done flag first, so every sync after the one that finished it
/// costs one preference read. The sync awaits it inside its single flight,
/// so no second sync overlaps a stamp. Contains its own failures: the sync
/// has already succeeded, and a backfill that could not run must not turn
/// it into an error.
// no-tick: the value is a CLOSURE, not a query result. Every read happens
// inside it at call time via ref.read, so there is no cached row to go stale.
final galleryOriginBackfillProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (GalleryOriginBackfill.isDone(prefs)) return;
      final photos = ref.read(photoPickerServiceProvider);
      await GalleryOriginBackfill(
        mediaRepository: ref.read(mediaRepositoryProvider),
        reader: const PhotoManagerAssetReader(),
        photos: photos,
        // Read, never asked: this runs after a sync, unasked. The desktop
        // service never prompts, so its checkPermission is already a read.
        permissionStatus: photos is PhotoPickerServiceMobile
            ? photos.currentPermission
            : photos.checkPermission,
        deviceId: () => SyncRepository().getDeviceId(),
        prefs: prefs,
      ).run();
    } on Object catch (e, stackTrace) {
      LoggerService.forClass(GalleryOriginBackfill).warning(
        'Could not run the gallery origin backfill',
        error: e,
        stackTrace: stackTrace,
      );
    }
  };
});
