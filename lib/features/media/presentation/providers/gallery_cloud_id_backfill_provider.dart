import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/cloud_identifier_source.dart';
import 'package:submersion/features/media/data/services/gallery_cloud_id_backfill.dart';
import 'package:submersion/features/media/data/services/photo_picker_service_mobile.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';

/// Runs [GalleryCloudIdBackfill] after a successful sync, once the origin
/// backfill is done, at most once a day. One preference read otherwise.
/// Contains its own failures: the sync has already succeeded.
// no-tick: the value is a CLOSURE, not a query result. Every read happens
// inside it at call time via ref.read, so there is no cached row to go stale.
final galleryCloudIdBackfillProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!GalleryCloudIdBackfill.isDue(prefs, DateTime.now())) return;
      final photos = ref.read(photoPickerServiceProvider);
      await GalleryCloudIdBackfill(
        mediaRepository: ref.read(mediaRepositoryProvider),
        cloudIdentifiers: const PhotoManagerCloudIdentifierSource(),
        photos: photos,
        // Read, never asked: this runs after a sync, unasked.
        permissionStatus: photos is PhotoPickerServiceMobile
            ? photos.currentPermission
            : photos.checkPermission,
        deviceId: () => SyncRepository().getDeviceId(),
        prefs: prefs,
        assetCache: ref.read(localAssetCacheRepositoryProvider),
      ).run();
    } on Object catch (e, stackTrace) {
      LoggerService.forClass(GalleryCloudIdBackfill).warning(
        'Could not run the gallery cloud id backfill',
        error: e,
        stackTrace: stackTrace,
      );
    }
  };
});
