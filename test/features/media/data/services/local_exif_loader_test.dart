import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/services/local_exif_loader.dart';

import '../../../../helpers/media_container_fixtures.dart';

/// A real TIFF/EXIF block lifted from an encoded JPEG's APP1 segment,
/// prefixed by the 4-byte tiff-header offset a HEIC `Exif` item carries.
List<int> exifItemPayload(void Function(img.ExifData) configure) {
  final jpg = jpegWithExif(configure);
  for (var i = 0; i + 3 < jpg.length; i++) {
    if (jpg[i] == 0xFF && jpg[i + 1] == 0xE1) {
      final segLen = (jpg[i + 2] << 8) | jpg[i + 3];
      return [...u32(6), ...jpg.sublist(i + 4, i + 2 + segLen)];
    }
  }
  throw StateError('no APP1 EXIF segment in encoded JPEG');
}

/// Minimal HEIC: ftyp, mdat holding the Exif payload, then meta whose iinf
/// declares an 'Exif' item and iloc points at the payload's absolute offset.
List<int> heicFile(void Function(img.ExifData) configure) {
  final ftyp = box('ftyp', 'heic'.codeUnits);
  final payload = exifItemPayload(configure);
  final mdat = box('mdat', payload);
  final payloadOffset = ftyp.length + 8;
  final infe = box('infe', [
    2, 0, 0, 0,
    ...u16(1), // item_ID
    ...u16(0), // protection_index
    ...'Exif'.codeUnits,
    0,
  ]);
  final iinf = box('iinf', [0, 0, 0, 0, ...u16(1), ...infe]);
  final iloc = box('iloc', [
    1, 0, 0, 0, // version 1 + flags
    0x44, // offset_size=4, length_size=4
    0x00, // base_offset_size=0, index_size=0
    ...u16(1), ...u16(1), // item_count, item_ID
    ...u16(0), // construction_method
    ...u16(0), // data_reference_index
    ...u16(1), // extent_count
    ...u32(payloadOffset),
    ...u32(payload.length),
  ]);
  final meta = box('meta', [0, 0, 0, 0, ...iinf, ...iloc]);
  return [...ftyp, ...mdat, ...meta];
}

void main() {
  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exif_loader_');
  });
  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });
  File write(String name, List<int> bytes) =>
      File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

  test('JPEG: returns the parsed EXIF block', () {
    final f = write(
      'a.jpg',
      jpegWithExif(
        (e) => e.exifIfd['DateTimeOriginal'] = '2025:12:27 12:08:19',
      ),
    );
    final exif = readLocalExif(f, 'image/jpeg');
    expect(exif?.exifIfd['DateTimeOriginal'].toString(), '2025:12:27 12:08:19');
  });

  test('HEIC: returns the EXIF block from the meta Exif item', () {
    final f = write(
      'a.heic',
      heicFile((e) {
        e.exifIfd['DateTimeOriginal'] = '2026:05:06 17:35:39';
        e.gpsIfd.gpsLatitude = 12.5;
        e.gpsIfd.gpsLatitudeRef = 'N';
      }),
    );
    final exif = readLocalExif(f, 'image/heic');
    expect(exif?.exifIfd['DateTimeOriginal'].toString(), '2026:05:06 17:35:39');
    expect(exif?.gpsIfd.gpsLatitude, closeTo(12.5, 1e-6));
  });

  test('returns null for other mimes, corrupt bytes, and missing files', () {
    final f = write('bad.jpg', [1, 2, 3]);
    expect(readLocalExif(f, 'image/jpeg'), isNull);
    expect(readLocalExif(f, 'video/mp4'), isNull);
    expect(
      readLocalExif(File('${tempDir.path}/none.jpg'), 'image/jpeg'),
      isNull,
    );
  });
}
