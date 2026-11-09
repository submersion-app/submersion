import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
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

/// The photos backing one check-in, for the check-in sheet.
final observationPhotosProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, observationId) async {
      final repository = ref.watch(gearPhotoRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchGearPhotoChanges());
      return repository.photosForObservation(observationId);
    });

/// The photo standing for an item, or null to show its type icon.
final equipmentCoverProvider = FutureProvider.family<MediaItem?, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(gearPhotoRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchGearPhotoChanges());
  return repository.coverFor(equipmentId);
});

/// The Gear gallery: photos of every item the viewing diver may see,
/// grouped by item.
final gearGalleryProvider = FutureProvider<List<GearPhotoGroup>>((ref) async {
  final repository = ref.watch(gearPhotoRepositoryProvider);
  final equipment = ref.watch(equipmentRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchGearPhotoChanges());
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final ids = await repository.equipmentIdsWithPhotos();
  final visible = diverId == null
      ? ids
      : await equipment.visibleIdsAmong(ids, diverId);
  return repository.gearGallery(visible);
});
