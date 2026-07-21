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

    test('unknown mvhd version returns null (falls back to mtime)', () async {
      // Spec allows only v0/v1. A corrupt byte here must not be parsed as v0,
      // which would emit a plausible-but-wrong timestamp.
      final badVersion = <int>[
        2, 0, 0, 0, // version 2 + flags
        ..._u32(goProRaw),
        ..._u32(0),
        ..._u32(1000),
        ..._u32(0),
      ];
      final f = File('${tempDir.path}/badver.mp4')
        ..writeAsBytesSync(_goProMp4(badVersion));
      expect(readLocalCaptureTime(f, 'video/mp4'), isNull);
    });

    test('truncated / non-MP4 bytes return null without throwing', () async {
      final f = File('${tempDir.path}/junk.mp4')
        ..writeAsBytesSync([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(readLocalCaptureTime(f, 'video/mp4'), isNull);
    });
  });

  group('HEIC/HEIF EXIF', () {
    List<int> u16(int v) => [(v >> 8) & 0xff, v & 0xff];

    // A real TIFF/EXIF block: encode a JPEG with the tag, then lift its APP1
    // payload. `image` can't encode HEIC, but a HEIC `Exif` item carries the
    // same "Exif\0\0" + TIFF payload, prefixed by a 4-byte tiff-header offset.
    List<int> exifItemPayload(String date, {int declaredOffset = 6}) {
      final image = img.Image(width: 2, height: 2);
      image.exif.exifIfd['DateTimeOriginal'] = date;
      final jpg = img.encodeJpg(image);
      for (var i = 0; i + 3 < jpg.length; i++) {
        if (jpg[i] == 0xFF && jpg[i + 1] == 0xE1) {
          final segLen = (jpg[i + 2] << 8) | jpg[i + 3];
          // 4-byte tiff-header offset (6 skips the "Exif\0\0" prefix) + payload.
          return [
            ..._u32(declaredOffset),
            ...jpg.sublist(i + 4, i + 2 + segLen),
          ];
        }
      }
      throw StateError('no APP1 EXIF segment in encoded JPEG');
    }

    // Minimal HEIC: ftyp, mdat holding the Exif payload, then meta whose
    // iinf declares an 'Exif' item and iloc points at the payload's absolute
    // offset (base_offset_size 0, construction_method 0).
    List<int> heicFile(
      String date, {
      int declaredOffset = 6,
      int ilocVersion = 1,
    }) {
      final ftyp = _box('ftyp', 'heic'.codeUnits);
      final payload = exifItemPayload(date, declaredOffset: declaredOffset);
      final mdat = _box('mdat', payload);
      final payloadOffset = ftyp.length + 8; // just past the mdat box header

      final infe = _box('infe', [
        2, 0, 0, 0, // version 2 + flags
        ...u16(1), // item_ID
        ...u16(0), // protection_index
        ...'Exif'.codeUnits, // item_type
        0, // item_name (empty)
      ]);
      final iinf = _box('iinf', [0, 0, 0, 0, ...u16(1), ...infe]);
      // iloc v2 widens item_count and item_ID to 32-bit (v0/v1 use 16-bit).
      final countAndId = ilocVersion >= 2
          ? [..._u32(1), ..._u32(1)]
          : [...u16(1), ...u16(1)];
      final iloc = _box('iloc', [
        ilocVersion, 0, 0, 0, // version + flags
        0x44, // offset_size=4, length_size=4
        0x00, // base_offset_size=0, index_size=0
        ...countAndId, // item_count + item_ID
        ...u16(0), // construction_method (v1/v2)
        ...u16(0), // data_reference_index
        ...u16(1), // extent_count
        ..._u32(payloadOffset), // extent_offset
        ..._u32(payload.length), // extent_length
      ]);
      final meta = _box('meta', [0, 0, 0, 0, ...iinf, ...iloc]);
      return [...ftyp, ...mdat, ...meta];
    }

    test('reads DateTimeOriginal from a HEIC Exif item', () async {
      final f = File('${tempDir.path}/photo.heic')
        ..writeAsBytesSync(heicFile('2026:05:06 17:35:39'));
      expect(
        readLocalCaptureTime(f, 'image/heic'),
        DateTime.utc(2026, 5, 6, 17, 35, 39),
      );
    });

    test('reads DateTimeOriginal from an iloc v2 container', () async {
      // iloc v2 widens item_count and item_ID to 32-bit (per ISO 14496-12;
      // v3 is an infe concept, not iloc). Confirms the version branch.
      final f = File('${tempDir.path}/v2.heic')
        ..writeAsBytesSync(heicFile('2026:05:06 17:35:39', ilocVersion: 2));
      expect(
        readLocalCaptureTime(f, 'image/heic'),
        DateTime.utc(2026, 5, 6, 17, 35, 39),
      );
    });

    test('image/heif mime is also handled', () async {
      final f = File('${tempDir.path}/photo.heif')
        ..writeAsBytesSync(heicFile('2026:05:06 17:35:39'));
      expect(
        readLocalCaptureTime(f, 'image/heif'),
        DateTime.utc(2026, 5, 6, 17, 35, 39),
      );
    });

    test('non-HEIC bytes for a heic mime return null (no throw)', () async {
      final f = File('${tempDir.path}/bad.heic')
        ..writeAsBytesSync([0, 1, 2, 3]);
      expect(readLocalCaptureTime(f, 'image/heic'), isNull);
    });

    test('meta box too small to hold version/flags returns null', () async {
      // An 8-byte meta box has no room for the 4 version/flags bytes; the
      // reader must reject it (no negative-length read) and fall back.
      final bytes = [
        ..._box('ftyp', 'heic'.codeUnits),
        ..._box('meta', <int>[]),
      ];
      final f = File('${tempDir.path}/tinymeta.heic')..writeAsBytesSync(bytes);
      expect(readLocalCaptureTime(f, 'image/heic'), isNull);
    });

    test(
      'falls back to scanning when the declared TIFF offset is bogus',
      () async {
        // Out-of-range declared offset: the reader must still find the TIFF via
        // its bounded scan rather than give up.
        final f = File('${tempDir.path}/badoffset.heic')
          ..writeAsBytesSync(
            heicFile('2026:05:06 17:35:39', declaredOffset: 99999),
          );
        expect(
          readLocalCaptureTime(f, 'image/heic'),
          DateTime.utc(2026, 5, 6, 17, 35, 39),
        );
      },
    );
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
