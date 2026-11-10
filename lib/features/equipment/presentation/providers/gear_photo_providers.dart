import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Gear photos (issue #3355).
final gearPhotoRepositoryProvider = Provider<GearPhotoRepository>(
  (ref) => GearPhotoRepository(),
);

/// An item's identification photos, newest first.
final identificationPhotosProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, equipmentId) async {
      final repository = ref.watch(gearPhotoRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchGearPhotoChanges());
      return repository.identificationPhotos(equipmentId);
    });

/// Every check-in photo of an item, keyed by check-in, for the Check-ins
/// card's one read.
final checkInPhotosProvider =
    FutureProvider.family<Map<String, List<MediaItem>>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(gearPhotoRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchGearPhotoChanges());
      return repository.photosByObservation(equipmentId);
    });

/// The photos backing one check-in, for the check-in sheet. Auto-disposed:
/// a new check-in's draft id is fresh every time the editor opens, so a
/// kept entry would never be read again.
final observationPhotosProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>((ref, observationId) async {
      final repository = ref.watch(gearPhotoRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchGearPhotoChanges());
      return repository.photosForObservation(observationId);
    });

/// The photo an item names as its cover, or null to show its type icon.
///
/// Keyed by the cover id the caller's item already holds, so a new choice
/// is a new key, and it re-reads only when photos or check-ins change, not
/// on every gear edit: a list of covered items would otherwise re-read
/// each cover whenever any item was saved.
final equipmentCoverProvider =
    FutureProvider.family<
      MediaItem?,
      ({String equipmentId, String coverMediaId})
    >((ref, key) async {
      final repository = ref.watch(gearPhotoRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchGearPhotoChanges());
      return repository.coverFor(key.equipmentId, key.coverMediaId);
    });

/// The Gear gallery: photos of every item the viewing diver may see,
/// grouped by item.
final gearGalleryProvider = FutureProvider<List<GearPhotoGroup>>((ref) async {
  final repository = ref.watch(gearPhotoRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchGearItemPhotoChanges());
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.gearGallery(diverId: diverId);
});
