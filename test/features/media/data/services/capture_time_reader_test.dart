import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/services/capture_time_reader.dart';

// Big-endian byte builders for hand-assembling MP4/MOV boxes.
List<int> _u32(int v) => [
  (v >> 24) & 0xff,
  (v >> 16) & 0xff,
  (v >> 8) & 0xff,
  v & 0xff,
];
List<int> _u64(int v) => [..._u32(v >> 32), ..._u32(v & 0xffffffff)];

/// A box is [size:uint32][type:4 ascii][payload]. When [largeSize] is set the
/// box uses the 64-bit form (size field == 1, followed by an 8-byte size).
List<int> _box(String type, List<int> payload, {bool largeSize = false}) {
  if (largeSize) {
    return [
      ..._u32(1),
      ...type.codeUnits,
      ..._u64(16 + payload.length),
      ...payload,
    ];
  }
  return [..._u32(8 + payload.length), ...type.codeUnits, ...payload];
}

List<int> _mvhdV0(int creationTime) => [
  0, 0, 0, 0, // version 0 + 3 flag bytes
  ..._u32(creationTime),
  ..._u32(0), // modification_time
  ..._u32(1000), // timescale
  ..._u32(0), // duration
];

List<int> _mvhdV1(int creationTime) => [
  1, 0, 0, 0, // version 1 + 3 flag bytes
  ..._u64(creationTime),
  ..._u64(0), // modification_time
  ..._u32(1000), // timescale
  ..._u64(0), // duration
];

/// Mirrors the real GoPro layout: ftyp, then a large mdat, then moov LAST.
List<int> _goProMp4(List<int> mvhd, {bool largeMdat = false}) => [
  ..._box('ftyp', 'isom'.codeUnits),
  ..._box('mdat', List<int>.filled(largeMdat ? 4096 : 8, 0)),
  ..._box('moov', _box('mvhd', mvhd)),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('capture_time_');
  });
  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('MP4/MOV creation_time', () {
    // Real value read from the user's GoPro Tortuga clip (GX015934-2.MP4):
    // mvhd creation_time raw = 3849681049 -> 2025-12-27 11:50:49 UTC, which
    // falls inside that dive's 11:26-12:09 window. Used here as the test vector.
    const goProRaw = 3849681049;
    final expected = DateTime.utc(2025, 12, 27, 11, 50, 49);

    test('reads mvhd v0 with moov after mdat (GoPro layout)', () async {
      final f = File('${tempDir.path}/gopro.mp4')
        ..writeAsBytesSync(_goProMp4(_mvhdV0(goProRaw)));
      expect(readLocalCaptureTime(f, 'video/mp4'), expected);
    });

    test('result is wall-clock UTC', () async {
      final f = File('${tempDir.path}/g.mp4')
        ..writeAsBytesSync(_goProMp4(_mvhdV0(goProRaw)));
      expect(readLocalCaptureTime(f, 'video/mp4')!.isUtc, isTrue);
    });

    test('reads mvhd v1 (64-bit creation_time)', () async {
      final f = File('${tempDir.path}/v1.mov')
        ..writeAsBytesSync(_goProMp4(_mvhdV1(goProRaw)));
      expect(readLocalCaptureTime(f, 'video/quicktime'), expected);
    });

    test('handles a large mdat without reading it all', () async {
      final f = File('${tempDir.path}/big.mp4')
        ..writeAsBytesSync(_goProMp4(_mvhdV0(goProRaw), largeMdat: true));
      expect(readLocalCaptureTime(f, 'video/mp4'), expected);
    });

    test('creation_time of 0 (unknown) returns null', () async {
      final f = File('${tempDir.path}/zero.mp4')
        ..writeAsBytesSync(_goProMp4(_mvhdV0(0)));
      expect(readLocalCaptureTime(f, 'video/mp4'), isNull);
    });

    test('truncated / non-MP4 bytes return null without throwing', () async {
      final f = File('${tempDir.path}/junk.mp4')
        ..writeAsBytesSync([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(readLocalCaptureTime(f, 'video/mp4'), isNull);
    });
  });

  group('JPEG EXIF (shared reader)', () {
    test('reads DateTimeOriginal from JPEG bytes', () async {
      final image = img.Image(width: 4, height: 4);
      image.exif.exifIfd['DateTimeOriginal'] = '2025:12:27 12:08:19';
      final f = File('${tempDir.path}/p.jpg')
        ..writeAsBytesSync(img.encodeJpg(image));
      expect(
        readLocalCaptureTime(f, 'image/jpeg'),
        DateTime.utc(2025, 12, 27, 12, 8, 19),
      );
    });

    test('unsupported mime returns null', () async {
      final f = File('${tempDir.path}/x.png')..writeAsBytesSync([0x89, 0x50]);
      expect(readLocalCaptureTime(f, 'image/png'), isNull);
    });
  });
}
