import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_gallery_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

SpeciesCrop _crop(String id) => SpeciesCrop(
  identificationId: id,
  mediaId: 'm_$id',
  box: const IdentificationBox(x: 0, y: 0, width: 1, height: 1),
  shorterSide: 100,
  isVideo: false,
  confirmed: true,
);

MediaItem _photo(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  takenAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ProviderContainer _container({
  Map<String, SpeciesCrop> coverCrops = const {},
  Map<String, MediaItem> coverPhotos = const {},
  Map<String, SpeciesCrop> best = const {},
  Map<String, MediaItem> newest = const {},
}) {
  final container = ProviderContainer(
    overrides: [
      speciesCoverCropsProvider.overrideWith((ref) async => coverCrops),
      speciesCoverPhotosProvider.overrideWith((ref) async => coverPhotos),
      speciesBestCropsProvider.overrideWith((ref) async => best),
      speciesCoverMediaProvider.overrideWith((ref) async => newest),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a cover crop beats the best crop', () async {
    final container = _container(
      coverCrops: {'grouper': _crop('cover')},
      best: {'grouper': _crop('best')},
    );

    final pictures = await container.read(speciesPicturesProvider.future);

    expect(pictures['grouper'], CropPicture(_crop('cover')));
  });

  test('a stale cover falls back to the best crop', () async {
    final container = _container(best: {'grouper': _crop('best')});

    final pictures = await container.read(speciesPicturesProvider.future);

    expect(pictures['grouper'], CropPicture(_crop('best')));
  });

  test('a species with only a tagged photo shows the photo', () async {
    final container = _container(newest: {'snapper': _photo('p1')});

    final pictures = await container.read(speciesPicturesProvider.future);

    expect(pictures['snapper'], PhotoPicture(_photo('p1')));
    expect(pictures['grouper'], isNull);
  });

  test('a failing source does not take the other pictures with it', () async {
    final container = ProviderContainer(
      overrides: [
        speciesCoverCropsProvider.overrideWith((ref) async => const {}),
        speciesCoverPhotosProvider.overrideWith((ref) async => const {}),
        speciesBestCropsProvider.overrideWith(
          (ref) async => {'grouper': _crop('best')},
        ),
        speciesCoverMediaProvider.overrideWith(
          (ref) async => throw StateError('no database'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final pictures = await container.read(speciesPicturesProvider.future);

    expect(pictures['grouper'], CropPicture(_crop('best')));
  });
}
