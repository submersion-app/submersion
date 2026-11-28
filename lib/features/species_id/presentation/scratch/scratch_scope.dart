import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/scratch/scratch_session.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/auto_applier.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/data/services/memory_readout.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

/// The overrides that point species identification at [session] instead of
/// the diver's logbook (issue #5122), for the subtree under the Identify
/// viewer.
///
/// Every store a result, tag or species is written to is replaced here,
/// and so is every service that writes. The providers the overlays read
/// are overridden too, with their own bodies: built in this scope, they
/// read the session's stores. (Declaring `dependencies` on them instead
/// would make every provider across the app that reads them throw.)
/// Nothing applies automatically: a file not kept carries only what the
/// diver chose.
///
/// [sharedPack] is the logbook service's loaded pack: the session's
/// service reads it rather than load a second copy of the catalogue and
/// its tables. Left out, the session loads its own.
List<Override> scratchOverrides(
  ScratchSession session, {
  Future<LoadedPack?> Function()? sharedPack,
}) => [
  mediaIdentificationRepositoryProvider.overrideWith(
    (ref) => MediaIdentificationRepository(database: session.logbook),
  ),
  identificationEmbeddingRepositoryProvider.overrideWith(
    (ref) => IdentificationEmbeddingRepository(database: session.cache),
  ),
  identificationCropRepositoryProvider.overrideWith(
    (ref) => IdentificationCropRepository(database: session.logbook),
  ),
  identificationCropStoreProvider.overrideWith((ref) {
    final store = IdentificationCropStore(
      supportPath: () async => session.cropRoot.path,
      table: ref.watch(identificationCropRepositoryProvider),
    );
    ref.onDispose(store.dispose);
    return store;
  }),
  mediaSpeciesRepositoryProvider.overrideWith(
    (ref) => MediaSpeciesRepository(database: session.logbook),
  ),
  speciesRepositoryProvider.overrideWith(
    (ref) => SpeciesRepository(database: session.logbook),
  ),
  speciesTaggingServiceProvider.overrideWith(
    (ref) => SpeciesTaggingService(
      tags: ref.watch(mediaSpeciesRepositoryProvider),
      media: ScratchMediaLookup(session),
      species: ref.watch(speciesRepositoryProvider),
    ),
  ),
  suggestionAcceptorProvider.overrideWith(
    (ref) => SuggestionAcceptor(species: ref.watch(speciesRepositoryProvider)),
  ),
  autoApplierProvider.overrideWith(
    (ref) => AutoApplier(
      identifications: ref.watch(mediaIdentificationRepositoryProvider),
      acceptor: ref.watch(suggestionAcceptorProvider),
      tagging: ref.watch(speciesTaggingServiceProvider),
      // Nothing is tagged for the diver on a file they have not kept.
      enabled: () => false,
      timing: () => ref.read(sightingTimingProvider),
      reconcile: (mediaId) =>
          ref.read(mediaIdentificationServiceProvider).reconcile(mediaId),
      databaseGeneration: () => 0,
      packAllows: () => false,
      deviceId: () async => null,
    ),
  ),
  // What the overlays read, as they read it, from the stores above.
  photoDetectionsProvider.overrideWith(readPhotoDetections),
  videoScanStretchesProvider.overrideWith(readVideoScanStretches),
  mediaAnalysisStatusProvider.overrideWith(readMediaAnalysisStatus),
  mediaSuggestionsProvider.overrideWith(readMediaSuggestions),
  mediaIdentificationProgressProvider.overrideWith(
    watchMediaIdentificationProgress,
  ),
  videoTracksProvider.overrideWith(readVideoTracks),
  mediaIdentificationBusyProvider.overrideWith(watchMediaIdentificationBusy),
  identificationCropProvider.overrideWith(readIdentificationCrop),
  presentCropIdsProvider.overrideWith(readPresentCropIds),
  mediaTagChipsProvider.overrideWith(readMediaTagChips),
  allSpeciesProvider.overrideWith(readAllSpecies),
  speciesProvider.overrideWith(readSpecies),
  speciesSearchProvider.overrideWith(readSpeciesSearch),
  speciesByCategoryProvider.overrideWith(readSpeciesByCategory),
  mediaIdentificationServiceProvider.overrideWith((ref) {
    final store = ref.watch(speciesPackStoreProvider);
    final identifications = ref.watch(mediaIdentificationRepositoryProvider);
    final engine = ref.watch(visionEngineProvider);
    final service = MediaIdentificationService(
      engine: engine,
      memoryReadout: MemoryReadout(engine: engine),
      loadPack:
          sharedPack ??
          () async {
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
      // Opening Identify is the diver asking for names.
      enabled: () => marineLifeIdEnabled,
      runEnabled: () => marineLifeIdEnabled,
      // The session's logbook never changes under it.
      databaseGeneration: () => 0,
      namingLevel: () => awaitLevelInForce(ref.container),
      chosenLevel: () => ref.read(namingLevelNotifierProvider),
    );
    ref.onDispose(service.dispose);
    return service;
  }),
];

/// The session's files, for the tagging service: it asks whether a photo is
/// on a dive, and a file not kept never is.
class ScratchMediaLookup extends MediaRepository {
  ScratchMediaLookup(this._session);

  final ScratchSession _session;

  @override
  Future<MediaItem?> getMediaById(String id) async =>
      _session.items.firstWhereOrNull((item) => item.id == id);
}
