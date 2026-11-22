import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/motion_photo.dart';

/// A tiny MP4: a 16-byte ftyp box and some payload.
List<int> _mp4([int payload = 20]) => [
  0, 0, 0, 16, ...ascii.encode('ftypmp42'), 0, 0, 0, 0, //
  ...List.filled(payload, 9),
];

/// A JPEG-shaped file: SOI, an APP1 with [xmp], image data, EOI, then
/// [tail] appended.
Uint8List _jpeg(String xmp, {List<int> tail = const []}) => Uint8List.fromList([
  0xFF, 0xD8, 0xFF, 0xE1, //
  ...latin1.encode(xmp),
  ...List.filled(30, 1),
  0xFF, 0xD9,
  ...tail,
]);

void main() {
  group('looksLikeMotionPhoto', () {
    test('reads the Motion Photo and MicroVideo markers', () {
      expect(
        looksLikeMotionPhoto(latin1.encode('GCamera:MotionPhoto="1"')),
        isTrue,
      );
      expect(
        looksLikeMotionPhoto(latin1.encode('<GCamera:MicroVideo>1<')),
        isTrue,
      );
      expect(
        looksLikeMotionPhoto(latin1.encode('Item:Semantic="MotionPhoto"')),
        isTrue,
      );
    });

    test('a plain photo is none', () {
      expect(
        looksLikeMotionPhoto(latin1.encode('GCamera:MotionPhoto="0"')),
        isFalse,
      );
      expect(looksLikeMotionPhoto(latin1.encode('just a jpeg')), isFalse);
    });
  });

  group('extractMotionVideo', () {
    test('cuts the clip the directory announces', () {
      final clip = _mp4();
      final file = _jpeg(
        '<Item:Item Item:Mime="video/mp4" Item:Semantic="MotionPhoto" '
        'Item:Length="${clip.length}" Item:Padding="0"/>',
        tail: clip,
      );
      expect(extractMotionVideo(file), clip);
    });

    test('reads the older MicroVideoOffset', () {
      final clip = _mp4(40);
      final file = _jpeg(
        'GCamera:MicroVideo="1" GCamera:MicroVideoOffset="${clip.length}"',
        tail: clip,
      );
      expect(extractMotionVideo(file), clip);
    });

    test('finds the clip after the image when the XMP does not say', () {
      final clip = _mp4();
      final file = _jpeg('GCamera:MotionPhoto="1"', tail: clip);
      expect(extractMotionVideo(file), clip);
    });

    test('a wrong length falls back to the box search', () {
      final clip = _mp4();
      final file = _jpeg(
        'Item:Semantic="MotionPhoto" Item:Length="7"',
        tail: clip,
      );
      expect(extractMotionVideo(file), clip);
    });

    test('a photo without a clip gives nothing', () {
      expect(extractMotionVideo(_jpeg('GCamera:MotionPhoto="0"')), isNull);
    });
  });
}
