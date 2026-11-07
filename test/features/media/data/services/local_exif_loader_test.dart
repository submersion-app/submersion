import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
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

/// The complete APP1 EXIF segment (marker, length and payload) that
/// `encodeJpg` writes for an image whose EXIF was populated by [configure].
List<int> exifSegment(void Function(img.ExifData) configure) {
  final jpg = jpegWithExif(configure);
  for (var i = 0; i + 3 < jpg.length; i++) {
    if (jpg[i] == 0xFF && jpg[i + 1] == 0xE1) {
      final segLen = (jpg[i + 2] << 8) | jpg[i + 3];
      return jpg.sublist(i, i + 2 + segLen);
    }
  }
  throw StateError('no APP1 EXIF segment in encoded JPEG');
}

/// An APPn segment holding [payload].
List<int> appSegment(int marker, List<int> payload) => [
  0xFF,
  marker,
  ...u16(2 + payload.length),
  ...payload,
];

/// A hand-assembled JPEG: SOI, the [before] segments, a baseline frame
/// header, a scan header, [scan] standing in for the entropy-coded data, EOI.
List<int> jpegBytes({List<int> before = const [], List<int> scan = const []}) =>
    [
      0xFF, 0xD8, // SOI
      ...before,
      0xFF, 0xC0, ...u16(11), 8, ...u16(4), ...u16(4), 1, 1, 0x11, 0, // SOF0
      0xFF, 0xDA, ...u16(8), 1, 1, 0, 0, 63, 0, // SOS, 1 component
      ...scan,
      0xFF, 0xD9, // EOI
    ];

void setDateAndGps(img.ExifData e) {
  e.exifIfd['DateTimeOriginal'] = '2025:12:27 12:08:19';
  e.gpsIfd.gpsLatitude = 12.5;
  e.gpsIfd.gpsLatitudeRef = 'N';
}

/// Counts every byte the loader pulls from disk, whichever way it reads.
class _CountingFile implements File {
  _CountingFile(this._inner);
  final File _inner;
  int bytesRead = 0;

  @override
  String get path => _inner.path;

  @override
  Uint8List readAsBytesSync() {
    final bytes = _inner.readAsBytesSync();
    bytesRead += bytes.length;
    return bytes;
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) =>
      _CountingRandomAccessFile(_inner.openSync(mode: mode), this);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _CountingRandomAccessFile implements RandomAccessFile {
  _CountingRandomAccessFile(this._inner, this._owner);
  final RandomAccessFile _inner;
  final _CountingFile _owner;

  @override
  Uint8List readSync(int count) {
    final bytes = _inner.readSync(count);
    _owner.bytesRead += bytes.length;
    return bytes;
  }

  @override
  RandomAccessFile setPositionSync(int position) {
    _inner.setPositionSync(position);
    return this;
  }

  @override
  int positionSync() => _inner.positionSync();

  @override
  int lengthSync() => _inner.lengthSync();

  @override
  void closeSync() => _inner.closeSync();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
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
      File(p.join(tempDir.path, name))..writeAsBytesSync(bytes);

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
      readLocalExif(File(p.join(tempDir.path, 'none.jpg')), 'image/jpeg'),
      isNull,
    );
  });
  group('JPEG bounded read', () {
    // Stands in for a camera photo's multi-MB entropy-coded scan.
    final bigScan = Uint8List(4 * 1024 * 1024);

    test('reads only the header segments of a large photo', () {
      final f = _CountingFile(
        write(
          'big.jpg',
          jpegBytes(before: exifSegment(setDateAndGps), scan: bigScan),
        ),
      );
      final exif = readLocalExif(f, 'image/jpeg');
      expect(
        exif?.exifIfd['DateTimeOriginal'].toString(),
        '2025:12:27 12:08:19',
      );
      expect(exif?.gpsIfd.gpsLatitude, closeTo(12.5, 1e-6));
      // One APP1 segment is at most 64 KB; nothing of the scan is read.
      expect(f.bytesRead, lessThan(64 * 1024));
    });

    test('stops at the scan when the photo has no EXIF', () {
      final f = _CountingFile(
        write(
          'plain.jpg',
          jpegBytes(
            before: appSegment(0xE0, 'JFIF\u0000'.codeUnits),
            scan: bigScan,
          ),
        ),
      );
      expect(readLocalExif(f, 'image/jpeg'), isNull);
      expect(f.bytesRead, lessThan(1024));
    });

    test('finds EXIF behind other APP segments', () {
      final f = write(
        'behind.jpg',
        jpegBytes(
          before: [
            ...appSegment(0xE0, 'JFIF\u0000'.codeUnits),
            // An XMP packet is APP1 too, but not EXIF.
            ...appSegment(0xE1, 'http://ns.adobe.com/xap/1.0/\u0000'.codeUnits),
            ...appSegment(0xE2, List.filled(60000, 0x5A)), // ICC profile
            // EXIF signature with a non-zero pad: not an EXIF block.
            ...appSegment(0xE1, [...'Exif'.codeUnits, 1, 0, 0x4D, 0x4D]),
            ...exifSegment(setDateAndGps),
          ],
        ),
      );
      final exif = readLocalExif(f, 'image/jpeg');
      expect(
        exif?.exifIfd['DateTimeOriginal'].toString(),
        '2025:12:27 12:08:19',
      );
      expect(exif?.gpsIfd.gpsLatitude, closeTo(12.5, 1e-6));
    });

    test('tolerates 0xFF fill bytes before a marker', () {
      final f = write(
        'fill.jpg',
        jpegBytes(before: [0xFF, 0xFF, ...exifSegment(setDateAndGps)]),
      );
      expect(
        readLocalExif(f, 'image/jpeg')?.exifIfd['DateTimeOriginal'].toString(),
        '2025:12:27 12:08:19',
      );
    });

    test('steps over stray bytes between segments, as decodeJpgExif did', () {
      final f = write(
        'junk.jpg',
        jpegBytes(
          before: [
            ...appSegment(0xE0, 'JFIF\u0000'.codeUnits),
            0x00, 0x12, 0xFF, 0x00, // junk, including a stuffed 0xFF00
            ...exifSegment(setDateAndGps),
          ],
        ),
      );
      expect(
        readLocalExif(f, 'image/jpeg')?.exifIfd['DateTimeOriginal'].toString(),
        '2025:12:27 12:08:19',
      );
    });

    test('returns null for truncated or malformed headers', () {
      final exif = exifSegment(setDateAndGps);
      // The EXIF segment's declared length runs past EOF.
      final truncated = write('truncated.jpg', [
        0xFF,
        0xD8,
        ...exif.sublist(0, exif.length ~/ 2),
      ]);
      // EXIF segment bytes without the SOI that makes them a JPEG.
      final noSoi = write('nosoi.jpg', [...exif, ...jpegBytes().sublist(2)]);
      expect(readLocalExif(truncated, 'image/jpeg'), isNull);
      expect(readLocalExif(noSoi, 'image/jpeg'), isNull);
    });

    test('gives up on a run of junk too long to be a sloppy writer', () {
      final f = _CountingFile(
        write(
          'runaway.jpg',
          jpegBytes(
            before: [...Uint8List(128 * 1024), ...exifSegment(setDateAndGps)],
            scan: bigScan,
          ),
        ),
      );
      expect(readLocalExif(f, 'image/jpeg'), isNull);
      expect(f.bytesRead, lessThan(128 * 1024));
    });

    test('budgets stray bytes across the whole walk, not per gap', () {
      // Junk with a stuffed 0xFF00 every KB: each gap is short, but the
      // walk as a whole must still give up.
      final junk = [
        for (var k = 0; k < 128; k++) ...[...List.filled(1022, 0x11), 0xFF, 0],
      ];
      final f = _CountingFile(
        write(
          'spread.jpg',
          jpegBytes(
            before: [...junk, ...exifSegment(setDateAndGps)],
            scan: bigScan,
          ),
        ),
      );
      expect(readLocalExif(f, 'image/jpeg'), isNull);
      expect(f.bytesRead, lessThan(128 * 1024));
    });

    test('budgets 0xFF fill bytes too', () {
      final f = _CountingFile(
        write(
          'padded.jpg',
          jpegBytes(
            before: [
              ...List.filled(1024 * 1024, 0xFF),
              ...exifSegment(setDateAndGps),
            ],
          ),
        ),
      );
      expect(readLocalExif(f, 'image/jpeg'), isNull);
      expect(f.bytesRead, lessThan(256 * 1024));
    });
  });
}
