import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';
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
        diveLocation: (diveId) async {
          final dive = await ref
              .read(diveRepositoryProvider)
              .getDiveById(diveId);
          return (
            exists: dive != null,
            site: dive?.site?.location,
            entry: dive?.entryLocation,
          );
        },
        request: (item, location) => service.requestFromRun(
          item,
          location: location,
          resolveImage: (i) => identificationImageOf(ref, i),
          resolveVideo: (i) => runVideoFileOf(ref, i),
        ),
        cancel: service.cancelRun,
        applyAll: (items) =>
            ref.read(autoApplierProvider).applyAllInScope(items),
        databaseGeneration: () => DatabaseService.instance.generation,
        inForeground: () =>
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      );
      final lifecycle = _RunLifecycle(run);
      WidgetsBinding.instance.addObserver(lifecycle);
      ref.onDispose(() => WidgetsBinding.instance.removeObserver(lifecycle));
      return run;
    });

/// Pauses a run while the app is in the background, where the models may
/// not run, and carries on when it is back.
class _RunLifecycle with WidgetsBindingObserver {
  _RunLifecycle(this._run);

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
