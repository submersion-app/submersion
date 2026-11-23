import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/platform/app_directories.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/data/streaming/video_playback_plan.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';
import 'package:submersion/features/media/presentation/providers/video_playback_providers.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';
import 'package:submersion/features/settings/presentation/providers/media_badge_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/serial_preference_writes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/data/engines/platform_vision_engine.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/auto_applier.dart';
import 'package:submersion/features/species_id/domain/services/auto_apply_rules.dart';
import 'package:submersion/features/species_id/data/services/identification_cleanup.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/data/services/named_crop_backfill.dart';
import 'package:submersion/features/species_id/data/services/naming_bars_fill.dart';
import 'package:submersion/features/species_id/data/services/memory_readout.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';
import 'package:submersion/features/species_id/data/services/video_identification_scan.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/naming_levels.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// Marine life identification (issue #4668).

final visionEngineProvider = Provider<VisionEngine>(
  (ref) => createPlatformVisionEngine(),
);

final visionAvailabilityProvider = FutureProvider<VisionAvailability>(
  (ref) => ref.watch(visionEngineProvider).availability(),
);

final speciesPackStoreProvider = Provider<SpeciesPackStore>((ref) {
  final engine = ref.watch(visionEngineProvider);
  return SpeciesPackStore(
    supportPath: AppDirectories.support,
    engine: engine.engineName ?? 'none',
    excludeFromBackup: engine.excludeFromBackup,
  );
});

/// The installed model pack, or null. Invalidated by whatever installs or
/// removes one.
final installedSpeciesPackProvider = FutureProvider<InstalledPack?>(
  (ref) => ref.watch(speciesPackStoreProvider).installed(),
);

/// Whether a photo is analysed when it is opened in the viewer. Per device,
/// on by default.
class IdentifyFishOnOpenNotifier extends DeviceBadgeToggleNotifier {
  IdentifyFishOnOpenNotifier(SharedPreferences prefs)
    : super(prefs, SettingsKeys.identifyFishOnOpen);

  /// Fixed state with nothing behind it; see
  /// [DeviceBadgeToggleNotifier.unstored].
  IdentifyFishOnOpenNotifier.unstored(bool enabled)
    : super.unstored(enabled, SettingsKeys.identifyFishOnOpen);
}

/// On, with no storage behind it; `rootProviderOverrides` gives it the
/// stored preference.
final identifyFishOnOpenProvider =
    StateNotifierProvider<IdentifyFishOnOpenNotifier, bool>(
      (ref) => IdentifyFishOnOpenNotifier.unstored(true),
    );

/// Whether matches the app is confident of are tagged with no tap (issue
/// #4727). Per device, off by default.
class AutoApplyNotifier extends DeviceBadgeToggleNotifier {
  AutoApplyNotifier(SharedPreferences prefs)
    : super(prefs, SettingsKeys.speciesIdAutoApply, defaultValue: false);

  /// Fixed state with nothing behind it; see
  /// [DeviceBadgeToggleNotifier.unstored].
  AutoApplyNotifier.unstored(bool enabled)
    : super.unstored(enabled, SettingsKeys.speciesIdAutoApply);
}

/// Off, with no storage behind it; `rootProviderOverrides` gives it the
/// stored preference.
final autoApplyProvider = StateNotifierProvider<AutoApplyNotifier, bool>(
  (ref) => AutoApplyNotifier.unstored(false),
);

/// When a tag the app applied logs its sighting (issue #4727). Per device,
/// [SightingTiming.onConfirm] by default.
class SightingTimingNotifier extends StateNotifier<SightingTiming>
    with SerialPreferenceWrites {
  SightingTimingNotifier(SharedPreferences prefs)
    : _prefs = prefs,
      super(
        SightingTiming.fromName(
          prefs.getString(SettingsKeys.speciesIdSightingTiming),
        ),
      );

  /// Fixed state with nothing behind it.
  SightingTimingNotifier.unstored(super.timing) : _prefs = null;

  final SharedPreferences? _prefs;

  Future<void> setTiming(SightingTiming timing) {
    if (state == timing) return Future<void>.value();
    state = timing;
    final prefs = _prefs;
    if (prefs == null) return Future<void>.value();
    return writeInTurn(
      () => prefs.setString(SettingsKeys.speciesIdSightingTiming, timing.name),
    );
  }
}

/// When I confirm, with no storage behind it; `rootProviderOverrides` gives
/// it the stored preference.
final sightingTimingProvider =
    StateNotifierProvider<SightingTimingNotifier, SightingTiming>(
      (ref) => SightingTimingNotifier.unstored(SightingTiming.onConfirm),
    );

/// How readily the app suggests a species (issue #4721). Per device,
/// [NamingLevel.byDefault] until the diver picks one (issue #4789); an id
/// this version does not know reads as Surer and is kept until another
/// level is chosen.
class NamingLevelNotifier extends StateNotifier<NamingLevel>
    with SerialPreferenceWrites {
  NamingLevelNotifier(SharedPreferences prefs)
    : this._stored(prefs, prefs.getString(SettingsKeys.marineLifeNamingLevel));

  NamingLevelNotifier._stored(SharedPreferences prefs, String? id)
    : _prefs = prefs,
      _picked = id != null,
      super(
        id == null
            ? NamingLevel.byDefault
            : NamingLevel.fromId(id) ?? NamingLevel.surer,
      );

  /// Fixed state with nothing behind it, as
  /// [DeviceBadgeToggleNotifier.unstored]. [picked] says whether [level]
  /// stands for a level the diver chose.
  NamingLevelNotifier.unstored(super.level, {required bool picked})
    : _prefs = null,
      _picked = picked;

  final SharedPreferences? _prefs;
  bool _picked;

  /// Whether the diver chose the level, rather than it being the default
  /// (issue #4789). It only turns true as the level itself changes, so a
  /// widget watching the level rebuilds with it.
  bool get picked => _picked;

  Future<void> setLevel(NamingLevel level) {
    if (state == level) return Future<void>.value();
    _picked = true;
    state = level;
    final prefs = _prefs;
    if (prefs == null) return Future<void>.value();
    return writeInTurn(
      () => prefs.setString(SettingsKeys.marineLifeNamingLevel, level.id),
    );
  }
}

/// The default level, unpicked, with no storage behind it;
/// `rootProviderOverrides` gives it the stored preference.
final namingLevelNotifierProvider =
    StateNotifierProvider<NamingLevelNotifier, NamingLevel>(
      (ref) =>
          NamingLevelNotifier.unstored(NamingLevel.byDefault, picked: false),
    );

/// The level the installed pack names at for the diver's choice, or null
/// with no pack (issue #4721). Never waits: while the pack is being read,
/// or when it cannot be, there is no level and suggestions show as they
/// were named; readers rebuild once it is known. Null for Surer, which
/// reads as the stored flags on any pack: the pack is not watched then, so
/// its reads and reloads rebuild no suggestions or tracks.
final levelInForceProvider = Provider<LevelInForce?>((ref) {
  final chosen = ref.watch(namingLevelNotifierProvider);
  if (chosen == NamingLevel.surer) return null;
  // Where no model can run there is no pack to read, and a browser has no
  // files to read one from: a run's own bars name its rows (issue #4876).
  if (!marineLifeIdEnabled) return null;
  final pack = ref.watch(installedSpeciesPackProvider).value;
  return levelInForce(pack?.manifest, chosen);
});

/// The level in force for a write that must not miss it (tag
/// reconciliation, issue #4721): none at once for Surer, which reads as the
/// stored flags; otherwise the pack's level once it is read, waiting
/// up to [wait] for a read still under way, a first one or one again after
/// an install, an update or an adopted manifest. None at once when the pack
/// cannot be read (never the one a failed read replaced), and none after
/// [wait]: a failed read retries in the background, and the video scan
/// awaits this, so it never waits on that. The read is held while it
/// waits, as an unheld one invalidated mid-load never completes (issue
/// #3807).
Future<LevelInForce?> awaitLevelInForce(
  ProviderContainer container, {
  Duration wait = const Duration(seconds: 5),
}) async {
  final chosen = container.read(namingLevelNotifierProvider);
  // Surer is in force on any pack and reads as the stored flags, so there
  // is nothing to wait for; nor is there where no model can run (issue
  // #4876), which has no pack to read.
  if (chosen == NamingLevel.surer || !marineLifeIdEnabled) return null;
  final current = container.read(installedSpeciesPackProvider);
  // A failed read may still hold the pack it was to replace, which may be
  // another version or carry other levels: it is not taken.
  if (current.hasError) return null;
  // A pack being read again still holds the one it replaces, for the same
  // reason: that read is waited for too.
  if (!current.isLoading) return levelInForce(current.value?.manifest, chosen);
  try {
    final pack = await container
        .awaitFuture(installedSpeciesPackProvider.future)
        .timeout(wait);
    return levelInForce(pack?.manifest, chosen);
  } on Object {
    return null;
  }
}

final mediaIdentificationRepositoryProvider =
    Provider<MediaIdentificationRepository>(
      (ref) => MediaIdentificationRepository(),
    );

final identificationEmbeddingRepositoryProvider =
    Provider<IdentificationEmbeddingRepository>(
      (ref) => IdentificationEmbeddingRepository(),
    );

/// The crops of named identifications, synced with the logbook (issue
/// #4876).
final identificationCropRepositoryProvider =
    Provider<IdentificationCropRepository>(
      (ref) => IdentificationCropRepository(),
    );

final identificationCropStoreProvider = Provider<IdentificationCropStore>((
  ref,
) {
  final store = IdentificationCropStore(
    supportPath: AppDirectories.support,
    table: ref.watch(identificationCropRepositoryProvider),
  );
  ref.onDispose(store.dispose);
  return store;
});

final identificationCleanupProvider = Provider<IdentificationCleanup>(
  (ref) => IdentificationCleanup(
    identifications: ref.watch(mediaIdentificationRepositoryProvider),
    embeddings: ref.watch(identificationEmbeddingRepositoryProvider),
    crops: ref.watch(identificationCropStoreProvider),
    deviceId: syncDeviceIdOrNull,
  ),
);

/// Identifications whose photo is gone, with their crops and embeddings,
/// swept once at app start (issue #4668): the one time no delete can be
/// held for undo, whose undo would want them back. Never throws.
Future<void> sweepIdentificationOrphansAtLaunch(
  IdentificationCleanup cleanup,
) async {
  // Results synced from another device are swept here too (issue #4876).
  if (!marineLifeLabelsShown) return;
  await cleanup.sweepOrphans();
}

/// The marine life steps at app start, one after another (issue #4876):
/// the orphan sweep first, so the crop backfill never moves a crop of
/// media the sweep is purging into the logbook and publishes it again;
/// then the naming bars, then the backfill. Never throws.
Future<void> runIdentificationLaunchSteps(ProviderContainer container) async {
  await sweepIdentificationOrphansAtLaunch(
    container.read(identificationCleanupProvider),
  );
  await fillIdentificationNamingBarsAtLaunch(container);
  await backfillNamedCropsAtLaunch(container);
}

/// Moves the crops of named identifications this device analysed before
/// crops synced into the logbook, once at app start (issue #4876). Never
/// throws.
Future<void> backfillNamedCropsAtLaunch(ProviderContainer container) async {
  if (!marineLifeIdEnabled) return;
  await NamedCropBackfill(
    identifications: container.read(mediaIdentificationRepositoryProvider),
    crops: container.read(identificationCropStoreProvider),
    deviceId: syncDeviceIdOrNull,
  ).run();
}

/// Gives this device's runs from before runs kept their naming bars the
/// installed pack's bars, once at app start (issue #4876). Never throws.
Future<void> fillIdentificationNamingBarsAtLaunch(
  ProviderContainer container,
) async {
  if (!marineLifeIdEnabled) return;
  await fillNamingBarsFromInstalledPack(
    installed: container.read(speciesPackStoreProvider).installed,
    identifications: container.read(mediaIdentificationRepositoryProvider),
    deviceId: syncDeviceIdOrNull,
  );
}

// Typed: it and [autoApplierProvider] read each other when called.
final Provider<MediaIdentificationService> mediaIdentificationServiceProvider =
    Provider<MediaIdentificationService>((ref) {
      final store = ref.watch(speciesPackStoreProvider);
      final identifications = ref.watch(mediaIdentificationRepositoryProvider);
      final engine = ref.watch(visionEngineProvider);
      final service = MediaIdentificationService(
        engine: engine,
        memoryReadout: MemoryReadout(engine: engine),
        loadPack: () async {
          final pack = await store.installed();
          return pack == null ? null : store.load(pack);
        },
        identifications: identifications,
        embeddings: ref.watch(identificationEmbeddingRepositoryProvider),
        crops: ref.watch(identificationCropStoreProvider),
        resolveImage: (item) => identificationImageOf(ref, item),
        resolveVideo: (item) => ref.read(videoFileReaderProvider(item).future),
        taggedSpecies: identifications.taggedSpecies,
        videoRuns: () => visionVideoRuns(defaultTargetPlatform),
        enabled: () =>
            marineLifeIdEnabled && ref.read(identifyFishOnOpenProvider),
        // A Find species run is the diver's own request (issue #4727).
        runEnabled: () => marineLifeIdEnabled,
        onItemSettled: (item, generation) => ref
            .read(autoApplierProvider)
            .applyInScope(
              item.id,
              isVideo: item.mediaType == MediaType.video,
              generation: generation,
            )
            .then((_) {}),
        // Waits for the installed pack, unlike [levelInForceProvider]: a
        // reconcile before it has been read would otherwise decide by the
        // stored flags, not the level the diver chose.
        namingLevel: () => awaitLevelInForce(ref.container),
        chosenLevel: () => ref.read(namingLevelNotifierProvider),
      );
      ref.onDispose(service.dispose);
      return service;
    });

/// The file the player opened for a video, read one call at a time
/// through its bookmark where it has one (issue #4675). Null when the video
/// does not play from a file here, or no player holds it: nothing is
/// resolved, so nothing is downloaded, for a scan.
///
/// Held while it resolves, as [resolvedFilePathProvider] is: the service
/// reads it once, keeping no listener, and finding the file takes real IO,
/// so an unheld provider would be disposed before its answer. It never
/// retries a failure: nothing would be listening for a second attempt.
final videoFileReaderProvider =
    FutureProvider.family<VideoFileReader?, MediaItem>(
      (ref, item) async {
        // Only the playback the player on screen holds: resolving one here
        // could fetch a whole original the diver never played (a load that
        // failed, a cache that let it go). A scan downloads nothing. The
        // player may hold it under an earlier copy of the item (issue
        // #4958): the newest such copy is read.
        final held = ref.exists(videoPlaybackProvider(item))
            ? item
            : ref
                  .read(liveVideoPlaybacksProvider)
                  .of(item.id)
                  .where((copy) => ref.exists(videoPlaybackProvider(copy)))
                  .lastOrNull;
        if (held == null) return null;
        final resolving = ref.keepAlive();
        try {
          final access = ref.read(videoFileAccessProvider);
          final playback = await ref.read(videoPlaybackProvider(held).future);
          if (playback is! FilePlayback) return null;
          final path = playback.path;
          return <T>(Future<T> Function(String path) read) =>
              access<T>(path: path, bookmarkRef: held.bookmarkRef, read: read);
        } finally {
          resolving.close();
        }
      },
      isAutoDispose: true,
      retry: (_, _) => null,
    );

/// A readable file when the photo has one here; otherwise the bytes the
/// viewer itself would show. Starts no download of its own beyond that.
Future<IdentificationImage?> identificationImageOf(
  Ref ref,
  MediaItem item,
) async {
  final local = item.localPath;
  if (local != null && local.isNotEmpty) {
    try {
      // Existence is not enough in a sandbox: the file must also open.
      await File(local).openRead(0, 1).drain<void>();
      return IdentificationImage.path(local);
    } on FileSystemException {
      // Fall through to the resolved bytes.
    }
  }
  final resolved = await ref.read(mediaBytesProvider(item).future);
  return resolved.isAvailable
      ? IdentificationImage.bytes(resolved.bytes!)
      : null;
}

/// What to offer for a photo, empty when the feature is off. Stored
/// suggestions show whether or not a model is installed.
final mediaSuggestionsProvider = FutureProvider.autoDispose
    .family<List<SpeciesSuggestion>, String>((ref, mediaId) async {
      if (!marineLifeLabelsShown) return const [];
      final repository = ref.watch(mediaIdentificationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      ref.invalidateSelfWhen(repository.watchTagChanges());
      final level = ref.watch(levelInForceProvider);
      final chosen = ref.watch(namingLevelNotifierProvider);
      return groupSuggestions(
        await identificationsAtLevel(
          repository,
          mediaId,
          level,
          chosen: chosen,
        ),
        await repository.taggedSpecies(mediaId),
      );
    });

/// How far the scan of a video has got, 0 to 1, while it is being
/// scanned; null otherwise (issue #4675).
final mediaIdentificationProgressProvider = StreamProvider.autoDispose
    .family<double?, String>((ref, mediaId) async* {
      final service = ref.watch(mediaIdentificationServiceProvider);
      yield service.progressOf(mediaId);
      await for (final _ in service.watchActivity()) {
        yield service.progressOf(mediaId);
      }
    });

/// The animals followed through a video, for the labels over it (issue
/// #4675). Empty when the feature is off.
final videoTracksProvider = FutureProvider.autoDispose
    .family<List<MediaIdentification>, String>((ref, mediaId) async {
      if (!marineLifeLabelsShown) return const [];
      final repository = ref.watch(mediaIdentificationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      final level = ref.watch(levelInForceProvider);
      final chosen = ref.watch(namingLevelNotifierProvider);
      return [
        for (final i in await identificationsAtLevel(
          repository,
          mediaId,
          level,
          chosen: chosen,
        ))
          if (i.isTrack) i,
      ];
    });

/// Whether the photo is being analysed, or waiting to be.
final mediaIdentificationBusyProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, mediaId) async* {
      final service = ref.watch(mediaIdentificationServiceProvider);
      yield service.isBusy(mediaId);
      await for (final _ in service.watchActivity()) {
        yield service.isBusy(mediaId);
      }
    });

/// Tags confident matches with no tap, when the setting is on (issue
/// #4727).
final Provider<AutoApplier> autoApplierProvider = Provider<AutoApplier>(
  (ref) => AutoApplier(
    identifications: ref.watch(mediaIdentificationRepositoryProvider),
    acceptor: ref.watch(suggestionAcceptorProvider),
    tagging: ref.watch(speciesTaggingServiceProvider),
    enabled: () => ref.read(autoApplyProvider),
    timing: () => ref.read(sightingTimingProvider),
    // Read when called: the service calls this applier from its own hook.
    reconcile: (mediaId) =>
        ref.read(mediaIdentificationServiceProvider).reconcile(mediaId),
    databaseGeneration: () => DatabaseService.instance.generation,
    // Off while the installed pack can never be confident, as its switch
    // shows; with none installed the stored names still count.
    packAllows: () {
      final installed = ref.read(installedSpeciesPackProvider).value;
      return installed == null || packCanApply(installed.manifest.naming);
    },
    deviceId: syncDeviceIdOrNull,
  ),
);

final suggestionAcceptorProvider = Provider<SuggestionAcceptor>(
  (ref) => SuggestionAcceptor(species: ref.watch(speciesRepositoryProvider)),
);

/// The crop of an identification: a file analysed here, or a named one's
/// from the logbook, whichever device analysed it (issue #4876); null when
/// this device holds neither. Looked for again when the photo's crops
/// change (an analysis stores its rows before it writes the crops), and
/// when a sync brings crops.
final identificationCropProvider = FutureProvider.autoDispose
    .family<
      IdentificationCropImage?,
      (String mediaId, String identificationId)
    >((ref, key) async {
      final store = ref.watch(identificationCropStoreProvider);
      final table = ref.watch(identificationCropRepositoryProvider);
      ref.invalidateSelfWhen(store.watchChanges().where((id) => id == key.$1));
      final crop = await store.read(key.$1, key.$2);
      // A synced crop is written once, so only one still to come is waited
      // for: a sync bringing other crops must not read this one again and
      // have its picture decoded and drawn anew.
      if (crop == null && ref.mounted) {
        ref.invalidateSelfWhen(table.watchChanges());
      }
      return crop;
    });

/// How many identifications the open logbook keeps.
final identificationCountProvider = FutureProvider.autoDispose<int>((ref) {
  final repository = ref.watch(mediaIdentificationRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.count();
});

/// What the crops take on this device. Follows the files themselves: a
/// clear deletes the rows before the crops.
final identificationCropBytesProvider = FutureProvider.autoDispose<int>((ref) {
  final store = ref.watch(identificationCropStoreProvider);
  ref.invalidateSelfWhen(store.watchChanges());
  return store.sizeBytes();
});
