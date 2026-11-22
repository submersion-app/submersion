import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/gallery_asset_reader.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';
import 'package:submersion/features/species_id/data/repositories/dive_place_repository.dart';
import 'package:submersion/features/species_id/data/services/dive_species_run.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/data/services/video_identification_scan.dart';
import 'package:submersion/features/species_id/domain/entities/dive_species_run_state.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

/// A video's file for a Find species run (issue #4727): resolved the way
/// playing it would, so a video not on this device is downloaded where
/// playing it would put it. The viewer's own scan never does this; a run
/// is the diver's request to look at everything.
Future<VideoFileReader?> runVideoFileOf(Ref ref, MediaItem item) async {
  final path = await ref.read(resolvedFilePathProvider(item).future);
  if (path == null) return null;
  final access = ref.read(videoFileAccessProvider);
  return <T>(Future<T> Function(String path) read) =>
      access<T>(path: path, bookmarkRef: item.bookmarkRef, read: read);
}

/// Whether a photo library item's original is on this device (issue
/// #4727): found in this device's library, with its original held here
/// rather than only in iCloud. Anything else (not found here, no access, a
/// failed check) a run would download, so it counts as not here.
final libraryOriginalHereProvider = Provider<Future<bool> Function(MediaItem)>(
  (ref) => (item) async {
    try {
      final resolved = await ref
          .read(assetResolutionServiceProvider)
          .resolveAssetId(item);
      final id = resolved.localAssetId;
      if (resolved.status != ResolutionStatus.resolved || id == null) {
        return false;
      }
      return await const PhotoManagerAssetReader().originIsLocal(id);
    } on Object {
      return false;
    }
  },
);

/// Where a dive is, for a Find species run (issue #4727).
final divePlaceRepositoryProvider = Provider<DivePlaceRepository>(
  (ref) => DivePlaceRepository(),
);

/// Find species runs, by dive (issue #4727). Lives for the app session, so
/// leaving the dive page does not stop a run.
final diveSpeciesRunProvider =
    StateNotifierProvider<DiveSpeciesRun, Map<String, DiveSpeciesRunState>>((
      ref,
    ) {
      final service = ref.watch(mediaIdentificationServiceProvider);
      final run = DiveSpeciesRun(
        mediaForDive: (diveId) =>
            ref.read(mediaRepositoryProvider).getMediaForDive(diveId),
        // Asked after every item: read lean, not the whole dive.
        diveLocation: ref.read(divePlaceRepositoryProvider).placeOf,
        request: (item, location) => service.requestFromRun(
          item,
          location: location,
          resolveImage: (i) => identificationImageOf(ref, i),
          resolveVideo: (i) => runVideoFileOf(ref, i),
        ),
        requestFresh: (item, location) => service.requestFromRun(
          item,
          location: location,
          resolveImage: (i) => identificationImageOf(ref, i),
          resolveVideo: (i) => runVideoFileOf(ref, i),
          fresh: true,
        ),
        cancel: service.cancelRun,
        applyAll: (items, generation) => ref
            .read(autoApplierProvider)
            .applyAllInScope(items, generation: generation),
        databaseGeneration: () => DatabaseService.instance.generation,
        inForeground: () =>
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      );
      final lifecycle = RunLifecycle(run);
      WidgetsBinding.instance.addObserver(lifecycle);
      ref.onDispose(() => WidgetsBinding.instance.removeObserver(lifecycle));
      return run;
    });

/// Pauses a run while the app is in the background, where the models may
/// not run, and carries on when it is back.
@visibleForTesting
class RunLifecycle with WidgetsBindingObserver {
  RunLifecycle(this._run);

  final DiveSpeciesRun _run;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only paused: a Mac window minimised or covered is hidden, and the
    // models run fine there; iOS reaches paused when it goes to the
    // background, where they may not.
    switch (state) {
      case AppLifecycleState.paused:
        _run.appPaused();
      case AppLifecycleState.resumed:
        _run.appResumed();
      case _:
        break;
    }
  }
}
