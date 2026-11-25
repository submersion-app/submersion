import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  group('extractMotionVideoFile', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('motion_photo_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final clip = _mp4(40);
    final cases = <String, (Uint8List, List<int>?)>{
      'the announced length': (
        _jpeg(
          'Item:Semantic="MotionPhoto" Item:Length="${clip.length}"',
          tail: clip,
        ),
        clip,
      ),
      'the older MicroVideoOffset': (
        _jpeg('GCamera:MicroVideoOffset="${clip.length}"', tail: clip),
        clip,
      ),
      'the box search': (_jpeg('GCamera:MotionPhoto="1"', tail: clip), clip),
      'a wrong length': (
        _jpeg('Item:Semantic="MotionPhoto" Item:Length="7"', tail: clip),
        clip,
      ),
      'no clip': (_jpeg('GCamera:MotionPhoto="0"'), null),
    };

    // Small chunks put the end-of-image marker and the ftyp box across a
    // seam between two reads; the last size reads the file in one piece.
    for (final MapEntry(key: name, value: (photo, expected)) in cases.entries) {
      for (final chunkSize in const [3, 5, 7, 16, 1 << 20]) {
        test('$name, read $chunkSize bytes at a time', () async {
          final source = File(p.join(dir.path, 'photo.jpg'));
          await source.writeAsBytes(photo);
          final target = File(p.join(dir.path, 'clip.mp4'));

          final found = await extractMotionVideoFile(
            source,
            target,
            chunkSize: chunkSize,
          );

          expect(found, expected != null);
          // The same answer as the in-memory reading.
          expect(extractMotionVideo(photo), expected);
          if (expected != null) {
            expect(await target.readAsBytes(), expected);
          } else {
            expect(await target.exists(), isFalse);
          }
        });
      }
    }
  });
}
