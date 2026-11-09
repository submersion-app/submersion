import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo_picker.dart';

CardPhoto _photo(String id) => CardPhoto(mediaId: id);

void main() {
  group('pickCardPhoto', () {
    test('returns null when the dive has no photos', () {
      expect(pickCardPhoto('dive-1', const []), isNull);
    });

    test('returns the only photo', () {
      final only = _photo('m1');
      expect(pickCardPhoto('dive-1', [only]), only);
    });

    test('picks the same photo every time for one dive', () {
      final photos = [for (var i = 0; i < 9; i++) _photo('m$i')];
      final first = pickCardPhoto('dive-42', photos);
      for (var i = 0; i < 20; i++) {
        expect(pickCardPhoto('dive-42', photos), first);
      }
    });

    test('ignores the order the photos arrive in', () {
      final photos = [for (var i = 0; i < 9; i++) _photo('m$i')];
      final shuffled = [...photos.reversed];
      expect(
        pickCardPhoto('dive-7', shuffled),
        pickCardPhoto('dive-7', photos),
      );
    });

    test('spreads the choice across photos for different dives', () {
      final photos = [for (var i = 0; i < 5; i++) _photo('m$i')];
      final chosen = {
        for (var d = 0; d < 50; d++) pickCardPhoto('dive-$d', photos)!.mediaId,
      };
      expect(chosen.length, greaterThan(1));
    });
  });

  group('cardPhotoHash', () {
    // The published FNV-1a 32-bit vectors. test/web/js_integers/ checks the
    // same values in a browser, where a plain multiply loses precision.
    test('matches the reference FNV-1a values', () {
      expect(cardPhotoHash(''), 0x811c9dc5);
      expect(cardPhotoHash('a'), 0xe40c292c);
      expect(cardPhotoHash('foobar'), 0xbf9cf968);
    });

    test('a dive picks the photo its hash names', () {
      final photos = [for (var i = 0; i < 9; i++) _photo('m$i')];
      // 0xbf9cf968 % 9 == 7; the web suite expects the same photo.
      expect(pickCardPhoto('foobar', photos)!.mediaId, 'm7');
    });
  });
}
