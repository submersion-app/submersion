import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/platform/app_directories.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/settings/presentation/providers/media_badge_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/data/engines/channel_vision_engine.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_cleanup.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// Marine life identification (issue #4668).

final visionEngineProvider = Provider<VisionEngine>(
  (ref) => ChannelVisionEngine(),
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

final mediaIdentificationRepositoryProvider =
    Provider<MediaIdentificationRepository>(
      (ref) => MediaIdentificationRepository(),
    );

final identificationEmbeddingRepositoryProvider =
    Provider<IdentificationEmbeddingRepository>(
      (ref) => IdentificationEmbeddingRepository(),
    );

final identificationCropStoreProvider = Provider<IdentificationCropStore>((
  ref,
) {
  final store = IdentificationCropStore(supportPath: AppDirectories.support);
  ref.onDispose(store.dispose);
  return store;
});

final identificationCleanupProvider = Provider<IdentificationCleanup>(
  (ref) => IdentificationCleanup(
    identifications: ref.watch(mediaIdentificationRepositoryProvider),
    embeddings: ref.watch(identificationEmbeddingRepositoryProvider),
    crops: ref.watch(identificationCropStoreProvider),
  ),
);

/// Identifications whose photo is gone, with their crops and embeddings,
/// swept once at app start (issue #4668): the one time no delete can be
/// held for undo, whose undo would want them back. Never throws.
Future<void> sweepIdentificationOrphansAtLaunch(
  IdentificationCleanup cleanup,
) async {
  if (!marineLifeIdEnabled) return;
  await cleanup.sweepOrphans();
}

final mediaIdentificationServiceProvider = Provider<MediaIdentificationService>(
  (ref) {
    final store = ref.watch(speciesPackStoreProvider);
    final identifications = ref.watch(mediaIdentificationRepositoryProvider);
    final service = MediaIdentificationService(
      engine: ref.watch(visionEngineProvider),
      loadPack: () async {
        final pack = await store.installed();
        return pack == null ? null : store.load(pack);
      },
      identifications: identifications,
      embeddings: ref.watch(identificationEmbeddingRepositoryProvider),
      crops: ref.watch(identificationCropStoreProvider),
      resolveImage: (item) => _imageOf(ref, item),
      taggedSpecies: identifications.taggedSpecies,
      enabled: () =>
          marineLifeIdEnabled && ref.read(identifyFishOnOpenProvider),
    );
    ref.onDispose(service.dispose);
    return service;
  },
);

/// A readable file when the photo has one here; otherwise the bytes the
/// viewer itself would show. Starts no download of its own beyond that.
Future<IdentificationImage?> _imageOf(Ref ref, MediaItem item) async {
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
      if (!marineLifeIdEnabled) return const [];
      final repository = ref.watch(mediaIdentificationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      ref.invalidateSelfWhen(repository.watchTagChanges());
      return groupSuggestions(
        await repository.forMedia(mediaId),
        await repository.taggedSpecies(mediaId),
      );
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

final suggestionAcceptorProvider = Provider<SuggestionAcceptor>(
  (ref) => SuggestionAcceptor(species: ref.watch(speciesRepositoryProvider)),
);

/// The crop file of an identification, or null when it is not on this
/// device. Looked for again when the photo's crops change: an analysis
/// stores its rows before it writes the crops.
final identificationCropFileProvider = FutureProvider.autoDispose
    .family<File?, (String mediaId, String identificationId)>((ref, key) async {
      final store = ref.watch(identificationCropStoreProvider);
      ref.invalidateSelfWhen(store.watchChanges().where((id) => id == key.$1));
      final file = await store.fileFor(key.$1, key.$2);
      return await file.exists() ? file : null;
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
