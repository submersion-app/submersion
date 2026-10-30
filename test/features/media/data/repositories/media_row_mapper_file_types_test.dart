import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

void main() {
  test('every non-photo spelling is one parseMediaType keeps from photos', () {
    // buddy_signature is the known gap: parseMediaType has no case for it
    // (see kSignatureFileTypes), but it is not a photo to count.
    final parsedAsPhoto = kNonPhotoFileTypes.where(
      (type) => parseMediaType(type) == MediaType.photo,
    );

    expect(parsedAsPhoto, ['buddy_signature']);
  });

  test('every spelling the mapper writes for a non-photo is listed', () {
    for (final type in MediaType.values) {
      if (type == MediaType.photo) continue;
      expect(kNonPhotoFileTypes, contains(mediaTypeToDbString(type)));
    }
    expect(
      kNonPhotoFileTypes,
      isNot(contains(mediaTypeToDbString(MediaType.photo))),
    );
  });
}
