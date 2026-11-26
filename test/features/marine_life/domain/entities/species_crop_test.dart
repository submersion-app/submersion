import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

SpeciesCrop _crop(String id, {int side = 100}) => SpeciesCrop(
  identificationId: id,
  mediaId: 'm_$id',
  box: const IdentificationBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
  shorterSide: side,
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

void main() {
  test('chooses the cover crop over the best crop', () {
    final picture = chooseSpeciesPicture(
      cover: _crop('cover', side: 50),
      bestCrop: _crop('best', side: 900),
      newestPhoto: _photo('p'),
    );
    expect(picture, CropPicture(_crop('cover', side: 50)));
  });

  test('a cover photo without a crop beats the best crop', () {
    final picture = chooseSpeciesPicture(
      coverPhoto: _photo('cover'),
      bestCrop: _crop('best'),
    );
    expect(picture, PhotoPicture(_photo('cover')));
  });

  test('falls back to the best crop, then the newest photo, then nothing', () {
    expect(
      chooseSpeciesPicture(bestCrop: _crop('best'), newestPhoto: _photo('p')),
      CropPicture(_crop('best')),
    );
    expect(
      chooseSpeciesPicture(newestPhoto: _photo('p')),
      PhotoPicture(_photo('p')),
    );
    expect(chooseSpeciesPicture(), const NoPicture());
  });

  test('copyWith keeps unchanged fields', () {
    final crop = _crop('a').copyWith(confirmed: false, bestMs: 1200);
    expect(crop.identificationId, 'a');
    expect(crop.confirmed, isFalse);
    expect(crop.bestMs, 1200);
  });
}
