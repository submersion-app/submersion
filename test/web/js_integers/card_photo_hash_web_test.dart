@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo_picker.dart';

/// The dive card photo hash in JavaScript, where a number holds integers
/// exactly only up to 2^53. FNV-1a's `hash * 16777619` reaches about 2^56,
/// so a plain multiply rounded away the low bits and the web build picked a
/// different photo for a dive than every native build. The VM suite in
/// test/features/dive_log/domain/card_photo/ cannot see it.
void main() {
  test('the hash matches the reference FNV-1a values', () {
    expect(cardPhotoHash(''), 0x811c9dc5);
    expect(cardPhotoHash('a'), 0xe40c292c);
    expect(cardPhotoHash('foobar'), 0xbf9cf968);
  });

  test('a dive picks the photo its hash names, as on native', () {
    final photos = [for (var i = 0; i < 9; i++) CardPhoto(mediaId: 'm$i')];
    // 0xbf9cf968 % 9 == 7, the photo a native build picks for this dive.
    expect(pickCardPhoto('foobar', photos)!.mediaId, 'm7');
  });
}
