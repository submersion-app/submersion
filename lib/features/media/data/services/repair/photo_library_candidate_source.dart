import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';

/// Harvests repair candidates from the device photo library, one date
/// window per broken row (takenAt within [window] on either side).
///
/// Reuses [PhotoPickerService] as the platform port -- the same date-range
/// query the picker's gallery tab runs -- so tests fake one interface and
/// the platform channel stays in one place. Gallery assets carry no cheap
/// byte hash, so candidates surface as probable; an accepted match converts
/// the row to platformGallery with the found asset id.
class PhotoLibraryCandidateSource implements CandidateSource {
  PhotoLibraryCandidateSource({
    required this.picker,
    this.window = const Duration(hours: 1),
  });

  final PhotoPickerService picker;
  final Duration window;

  @override
  Future<CandidateHarvest> harvest(List<MediaItem> brokenRows) async {
    final byFilename = <String, List<RepairCandidate>>{};

    for (final item in brokenRows) {
      final filename = item.originalFilename?.toLowerCase();
      if (filename == null || filename.isEmpty) continue;

      final assets = await picker.getAssetsInDateRange(
        item.takenAt.subtract(window),
        item.takenAt.add(window),
      );
      for (final asset in assets) {
        byFilename
            .putIfAbsent(filename, () => [])
            .add(
              RepairCandidate.galleryAsset(assetId: asset.id, sizeBytes: null),
            );
      }
    }

    return CandidateHarvest(byFilename: byFilename);
  }
}
