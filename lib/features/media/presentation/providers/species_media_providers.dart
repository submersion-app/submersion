import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_candidate_group.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

final mediaSpeciesRepositoryProvider = Provider<MediaSpeciesRepository>((ref) {
  return MediaSpeciesRepository();
});

final speciesTaggingServiceProvider = Provider<SpeciesTaggingService>((ref) {
  return SpeciesTaggingService(
    tags: ref.watch(mediaSpeciesRepositoryProvider),
    media: ref.watch(mediaRepositoryProvider),
    species: ref.watch(speciesRepositoryProvider),
  );
});

/// Photo-tag rows per species, the twin of `speciesSightingCountsProvider`:
/// the catalog manager refuses to delete a species that either one counts.
final speciesTagCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(mediaSpeciesRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTagChanges());
  return repository.tagCountsBySpecies();
});

/// Every photo tagged with a species, newest first, for the current diver.
///
/// Not scoped by the Statistics filter: the species detail page is a
/// logbook surface. Ticks on tags and on media (a photo edit, unlink or
/// delete changes the gallery without touching `media_species`).
final mediaForSpeciesProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  speciesId,
) async {
  final repository = ref.watch(mediaSpeciesRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  ref.invalidateSelfWhen(repository.watchTagChanges());
  ref.invalidateSelfWhen(
    ref.watch(mediaRepositoryProvider).watchMediaChanges(),
  );
  return repository.getMediaForSpecies(speciesId, diverId: diverId);
});

/// Untagged photos on the dives where the species was sighted, grouped by
/// dive. Also ticks on sightings: logging the species on another dive
/// brings that dive's photos into the picker.
final speciesTagCandidatesProvider =
    FutureProvider.family<List<SpeciesTagCandidateGroup>, String>((
      ref,
      speciesId,
    ) async {
      final repository = ref.watch(mediaSpeciesRepositoryProvider);
      final speciesRepository = ref.watch(speciesRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      ref.invalidateSelfWhen(repository.watchTagChanges());
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      ref.invalidateSelfWhen(speciesRepository.watchSightingChanges());
      return repository.getTagCandidatesForSpecies(speciesId, diverId: diverId);
    });

/// The species tags on one photo, as the viewer's chips show them. Ticks on
/// species too, so a renamed custom species relabels its chip.
final mediaTagChipsProvider =
    FutureProvider.family<List<SpeciesTagChip>, String>((ref, mediaId) async {
      final repository = ref.watch(mediaSpeciesRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTagChanges());
      ref.invalidateSelfWhen(
        ref.watch(speciesRepositoryProvider).watchSpeciesChanges(),
      );
      return repository.getTagChipsForMedia(mediaId);
    });

/// Newest tagged photo per species, for the Species page's tile avatars.
/// One query for the whole list; derived, never chosen (built-in species
/// rows never sync, so a chosen cover could not follow the diver).
final speciesCoverMediaProvider = FutureProvider<Map<String, MediaItem>>((
  ref,
) async {
  final repository = ref.watch(mediaSpeciesRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  ref.invalidateSelfWhen(repository.watchTagChanges());
  ref.invalidateSelfWhen(
    ref.watch(mediaRepositoryProvider).watchMediaChanges(),
  );
  return repository.getCoverMediaBySpecies(diverId: diverId);
});

/// How many photos on one dive carry each species tag, for the sighting
/// rows' photo chips.
final diveSpeciesPhotoCountsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, diveId) async {
      final repository = ref.watch(mediaSpeciesRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTagChanges());
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      return repository.getPhotoCountsBySpeciesForDive(diveId);
    });

/// Identifies one dive's photos of one species.
typedef DiveSpeciesKey = ({String diveId, String speciesId});

/// The photos on [DiveSpeciesKey.diveId] tagged with
/// [DiveSpeciesKey.speciesId], in the species gallery's order: that gallery
/// narrowed to one dive, so the viewer opened from a sighting row shows the
/// same photos the Species page would.
final mediaForDiveSpeciesProvider =
    FutureProvider.family<List<MediaItem>, DiveSpeciesKey>((ref, key) async {
      final repository = ref.watch(mediaSpeciesRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      ref.invalidateSelfWhen(repository.watchTagChanges());
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      return repository.getMediaForSpecies(
        key.speciesId,
        diverId: diverId,
        diveId: key.diveId,
      );
    });
