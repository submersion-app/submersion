import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_cover_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_facts_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_gallery_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_practice_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species_cover.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/domain/practice/leitner.dart';
import 'package:submersion/features/marine_life/domain/species_grouping.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';

/// Providers behind the Species pages' pictures, groupings, charts, covers
/// and practice (issue #5027). Every read is scoped to the current diver
/// and refreshed by the tables it reads.

const _log = LoggerService('SpeciesGalleryProviders');

final speciesGalleryRepositoryProvider = Provider<SpeciesGalleryRepository>(
  (ref) => SpeciesGalleryRepository(),
);

final speciesFactsRepositoryProvider = Provider<SpeciesFactsRepository>(
  (ref) => SpeciesFactsRepository(),
);

final speciesCoverRepositoryProvider = Provider<SpeciesCoverRepository>(
  (ref) => SpeciesCoverRepository(),
);

final speciesPracticeRepositoryProvider = Provider<SpeciesPracticeRepository>(
  (ref) => SpeciesPracticeRepository(),
);

/// The ticks every crop and cover read follows.
void _invalidateOnGalleryChanges(Ref ref) {
  ref.invalidateSelfWhen(
    ref.watch(speciesGalleryRepositoryProvider).watchChanges(),
  );
  ref.invalidateSelfWhen(
    ref.watch(speciesCoverRepositoryProvider).watchChanges(),
  );
}

/// The best crop of each species.
final speciesBestCropsProvider = FutureProvider<Map<String, SpeciesCrop>>((
  ref,
) async {
  final diverId = ref.watch(currentDiverIdProvider);
  _invalidateOnGalleryChanges(ref);
  return ref
      .watch(speciesGalleryRepositoryProvider)
      .bestCropBySpecies(diverId: diverId);
});

/// One crop per media item of a species, newest first.
final speciesCropsProvider = FutureProvider.family<List<SpeciesCrop>, String>((
  ref,
  speciesId,
) async {
  final diverId = ref.watch(currentDiverIdProvider);
  _invalidateOnGalleryChanges(ref);
  return ref
      .watch(speciesGalleryRepositoryProvider)
      .cropsForSpecies(speciesId, diverId: diverId);
});

/// Each species' valid cover crop.
final speciesCoverCropsProvider = FutureProvider<Map<String, SpeciesCrop>>((
  ref,
) async {
  final diverId = ref.watch(currentDiverIdProvider);
  _invalidateOnGalleryChanges(ref);
  if (diverId == null) return const {};
  return ref
      .watch(speciesGalleryRepositoryProvider)
      .coverCrops(diverId: diverId);
});

/// Each species' valid cover photo (a cover without a crop).
final speciesCoverPhotosProvider = FutureProvider<Map<String, MediaItem>>((
  ref,
) async {
  final diverId = ref.watch(currentDiverIdProvider);
  _invalidateOnGalleryChanges(ref);
  if (diverId == null) return const {};
  final ids = await ref
      .watch(speciesGalleryRepositoryProvider)
      .coverPhotoIds(diverId: diverId);
  if (ids.isEmpty) return const {};
  final items = await ref
      .watch(mediaRepositoryProvider)
      .getMediaByIds(ids.values.toSet().toList());
  final byId = {for (final item in items) item.id: item};
  return {for (final entry in ids.entries) entry.key: ?byId[entry.value]};
});

/// The covers as chosen, valid or not, for the strip's menu.
final speciesCoversProvider = FutureProvider<Map<String, SpeciesCover>>((
  ref,
) async {
  final diverId = ref.watch(currentDiverIdProvider);
  _invalidateOnGalleryChanges(ref);
  if (diverId == null) return const {};
  return ref.watch(speciesCoverRepositoryProvider).coversFor(diverId);
});

/// The picture that stands for each species: cover, best crop, newest
/// tagged photo. A species with none is absent.
final speciesPicturesProvider = FutureProvider<Map<String, SpeciesPicture>>((
  ref,
) async {
  // Each source on its own: one that fails costs only its own pictures,
  // never every card's.
  Future<Map<String, T>> orEmpty<T>(Future<Map<String, T>> source) async {
    try {
      return await source;
    } catch (e, stackTrace) {
      _log.error(
        'A species picture source failed',
        error: e,
        stackTrace: stackTrace,
      );
      return const {};
    }
  }

  final coverCrops = await orEmpty(ref.watch(speciesCoverCropsProvider.future));
  final coverPhotos = await orEmpty(
    ref.watch(speciesCoverPhotosProvider.future),
  );
  final best = await orEmpty(ref.watch(speciesBestCropsProvider.future));
  final newest = await orEmpty(ref.watch(speciesCoverMediaProvider.future));
  final ids = {
    ...coverCrops.keys,
    ...coverPhotos.keys,
    ...best.keys,
    ...newest.keys,
  };
  return {
    for (final id in ids)
      id: chooseSpeciesPicture(
        cover: coverCrops[id],
        coverPhoto: coverPhotos[id],
        bestCrop: best[id],
        newestPhoto: newest[id],
      ),
  };
});

/// Where each species was seen, for the Trip and Site groupings.
final speciesPlacesProvider = FutureProvider<SpeciesPlaces>((ref) async {
  final diverId = ref.watch(currentDiverIdProvider);
  invalidateOnSeenSpeciesChanges(ref);
  return ref.watch(speciesFactsRepositoryProvider).places(diverId: diverId);
});

/// Dives that saw a species in each calendar month, January first.
final speciesMonthCountsProvider = FutureProvider.family<List<int>, String>((
  ref,
  speciesId,
) async {
  final diverId = ref.watch(currentDiverIdProvider);
  invalidateOnSeenSpeciesChanges(ref);
  return ref
      .watch(speciesFactsRepositoryProvider)
      .monthCounts(speciesId, diverId: diverId);
});

/// The depths, in meters, at which the diver photographed a species.
final speciesPhotoDepthsProvider = FutureProvider.family<List<double>, String>((
  ref,
  speciesId,
) async {
  final diverId = ref.watch(currentDiverIdProvider);
  invalidateOnSeenSpeciesChanges(ref);
  final facts = ref.watch(speciesFactsRepositoryProvider);
  ref.invalidateSelfWhen(facts.watchDepthChanges());
  return facts.photoDepths(speciesId, diverId: diverId);
});

/// The diver's practice record per species.
final speciesPracticeStatesProvider =
    FutureProvider<Map<String, PracticeState>>((ref) async {
      final diverId = ref.watch(currentDiverIdProvider);
      final repository = ref.watch(speciesPracticeRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      if (diverId == null) return const {};
      return repository.statesFor(diverId);
    });

/// The confirmed crops practice may show, per life-list species.
final speciesPracticePoolProvider =
    FutureProvider<Map<String, List<SpeciesCrop>>>((ref) async {
      final diverId = ref.watch(currentDiverIdProvider);
      _invalidateOnGalleryChanges(ref);
      invalidateOnSeenSpeciesChanges(ref);
      return ref
          .watch(speciesGalleryRepositoryProvider)
          .practicePool(diverId: diverId);
    });
