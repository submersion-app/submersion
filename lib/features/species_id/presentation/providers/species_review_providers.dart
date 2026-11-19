import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/data/repositories/species_review_repository.dart';
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
        withSuggestions: marineLifeIdEnabled,
        // The library's rule: the active diver's dives and media on none.
        diverId: ref.watch(currentDiverIdProvider),
        level: marineLifeIdEnabled ? ref.watch(levelInForceProvider) : null,
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
    reconcile: (mediaId) => marineLifeIdEnabled
        ? ref.read(mediaIdentificationServiceProvider).reconcile(mediaId)
        : Future<void>.value(),
  ),
);

/// Whether every photo and video of [diveId] has been looked at with the
/// installed model (a video to its end), so a Find species run would do
/// nothing new (issue #4727). False with no model installed.
final diveSpeciesCheckedProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, diveId) async {
      final identifications = ref.watch(mediaIdentificationRepositoryProvider);
      ref.invalidateSelfWhen(identifications.watchChanges());
      final installed = await ref.watch(installedSpeciesPackProvider.future);
      if (installed == null) return false;
      final media = await ref.watch(mediaForDiveProvider(diveId).future);
      for (final item in media) {
        final video = item.mediaType == MediaType.video;
        if (!video && item.mediaType != MediaType.photo) continue;
        final run = await identifications.runFor(item.id);
        if (run == null ||
            run.packVersion != installed.manifest.packVersion ||
            (video && !run.scanComplete)) {
          return false;
        }
      }
      return true;
    });
