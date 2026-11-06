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
}
