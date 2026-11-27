import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_location.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/data/repositories/species_review_repository.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/data/services/species_review_saver.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/species_review_rules.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

final speciesReviewRepositoryProvider = Provider<SpeciesReviewRepository>(
  (ref) => SpeciesReviewRepository(
    tags: ref.watch(mediaSpeciesRepositoryProvider),
    identifications: ref.watch(mediaIdentificationRepositoryProvider),
    media: ref.watch(mediaRepositoryProvider),
    species: ref.watch(speciesRepositoryProvider),
    dives: ref.watch(diveRepositoryProvider),
  ),
);

/// What Species to review lists for [scope] (issue #4727). Suggestions
/// only where marine life identification runs; the app's tags everywhere.
final speciesReviewProvider = FutureProvider.autoDispose
    .family<List<ReviewGroup>, ReviewScope>((ref, scope) async {
      final repository = ref.watch(speciesReviewRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.load(
        scope,
        withSuggestions: marineLifeLabelsShown,
        // The library's rule: the active diver's dives and media on none.
        diverId: ref.watch(currentDiverIdProvider),
        level: marineLifeLabelsShown ? ref.watch(levelInForceProvider) : null,
        chosen: marineLifeLabelsShown
            ? ref.watch(namingLevelNotifierProvider)
            : null,
      );
    });

/// How many species [scope] has to review: the dive card's link and the
/// Species page's banner.
final speciesReviewCountProvider = FutureProvider.autoDispose
    .family<int, ReviewScope>(
      (ref, scope) async =>
          reviewCount(await ref.watch(speciesReviewProvider(scope).future)),
    );

/// Writes Species to review's decisions (issue #4727). Suggestions are
/// dismissed and decisions reconciled only where marine life identification
/// runs: elsewhere there are none on this device.
final speciesReviewSaverProvider = Provider<SpeciesReviewSaver>(
  (ref) => SpeciesReviewSaver(
    tagging: ref.watch(speciesTaggingServiceProvider),
    acceptor: ref.watch(suggestionAcceptorProvider),
    dismiss: (mediaId, ids) =>
        ref.read(mediaIdentificationServiceProvider).reject(mediaId, ids),
    reconcile: (mediaId) => marineLifeLabelsShown
        ? ref.read(mediaIdentificationServiceProvider).reconcile(mediaId)
        : Future<void>.value(),
    taggedSpecies: ref
        .watch(mediaIdentificationRepositoryProvider)
        .taggedSpecies,
  ),
);

/// The photos and videos of [diveId] a Find species run would find nothing
/// to do on (issue #4727), by the rule processing applies: looked at with
/// the installed models for the dive's place, crops on this device, a video
/// scanned to its end. Empty with no model installed.
final diveMediaUpToDateProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, diveId) async {
      final identifications = ref.watch(mediaIdentificationRepositoryProvider);
      ref.invalidateSelfWhen(identifications.watchChanges());
      final installed = await ref.watch(installedSpeciesPackProvider.future);
      if (installed == null) return const {};
      // Its place names the media: a site set since a run names them again.
      final dive = await ref.watch(diveProvider(diveId).future);
      final media = [
        for (final m in await ref.watch(mediaForDiveProvider(diveId).future))
          if (_looksAt(m)) m,
      ];
      // An analysis writes its crops after its rows, so follow the crops
      // too. Subscribed once the media are known: a crop written before
      // this is on disk when they are read below.
      final ids = {for (final m in media) m.id};
      ref.invalidateSelfWhen(
        ref
            .watch(identificationCropStoreProvider)
            .watchChanges()
            .where(ids.contains),
      );
      return ref
          .watch(mediaIdentificationServiceProvider)
          .upToDate(
            media,
            manifest: installed.manifest,
            locationOf: (m) => mediaLocation(
              m,
              siteLocation: dive?.site?.location,
              entryLocation: dive?.entryLocation,
            ),
          );
    });

/// Whether every photo and video of [diveId] is up to date
/// ([diveMediaUpToDateProvider]), so a Find species run would do nothing
/// new. False with no model installed.
final diveSpeciesCheckedProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, diveId) async {
      if (await ref.watch(installedSpeciesPackProvider.future) == null) {
        return false;
      }
      final media = await ref.watch(mediaForDiveProvider(diveId).future);
      final current = await ref.watch(diveMediaUpToDateProvider(diveId).future);
      return media.every((m) => !_looksAt(m) || current.contains(m.id));
    });

/// Whether marine life identification looks at [item]: photos and videos.
bool _looksAt(MediaItem item) =>
    item.mediaType == MediaType.photo || item.mediaType == MediaType.video;
