import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/isobmff_boxes.dart';

import '../../../../helpers/media_container_fixtures.dart';

void main() {
  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isobmff_');
  });
  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  File write(String name, List<int> bytes) =>
      File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

  group('findBox over a file', () {
    test('returns the payload range of the first matching sibling', () {
      final f = write('a.mp4', [
        ...box('ftyp', 'isom'.codeUnits),
        ...box('moov', [1, 2, 3]),
      ]);
      final raf = f.openSync();
      addTearDown(raf.closeSync);
      final moov = findBox(raf, 0, raf.lengthSync(), 'moov');
      expect(moov, isNotNull);
      expect(moov!.start, 12 + 8);
      expect(moov.end, 12 + 8 + 3);
      expect(moov.length, 3);
    });

    test('handles the 64-bit size form', () {
      final f = write('b.mp4', [
        ...box('mdat', [0, 0], largeSize: true),
        ...box('moov', [9]),
      ]);
      final raf = f.openSync();
      addTearDown(raf.closeSync);
      final moov = findBox(raf, 0, raf.lengthSync(), 'moov');
      expect(moov, isNotNull);
      expect(readByteAt(raf, moov!.start), 9);
    });

    test('returns null for a missing type or a corrupt size', () {
      final f = write('c.mp4', [...u32(3), ...'moov'.codeUnits]);
      final raf = f.openSync();
      addTearDown(raf.closeSync);
      expect(findBox(raf, 0, raf.lengthSync(), 'moov'), isNull);
      expect(findBox(raf, 0, raf.lengthSync(), 'trak'), isNull);
    });

    test('findBoxes returns every sibling of the type in order', () {
      final f = write('d.mp4', [
        ...box('trak', [1]),
        ...box('udta', [0]),
        ...box('trak', [2]),
      ]);
      final raf = f.openSync();
      addTearDown(raf.closeSync);
      final traks = findBoxes(raf, 0, raf.lengthSync(), 'trak');
      expect(traks.map((r) => readByteAt(raf, r.start)), [1, 2]);
    });
  });

  group('byte-buffer twins', () {
    test('findBoxInBytes and findBoxesInBytes mirror the file walkers', () {
      final bytes = Uint8List.fromList([
        ...box('keys', [1]),
        ...box('ilst', [2]),
        ...box('ilst', [3]),
      ]);
      final one = findBoxInBytes(bytes, 0, bytes.length, 'ilst');
      expect(one, isNotNull);
      expect(bytes[one!.start], 2);
      final all = findBoxesInBytes(bytes, 0, bytes.length, 'ilst');
      expect(all.map((r) => bytes[r.start]), [2, 3]);
    });

    test('big-endian readers', () {
      final b = Uint8List.fromList([
        0xff, 0xfe, // beU16 = 65534, beS16 = -2
        0xff, 0xff, 0xff, 0xfe, // beU32 = 4294967294, beS32 = -2
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, // beU64 = 1 << 32
        0x67, 0x70, 0x6d, 0x64, // 'gpmd'
      ]);
      expect(beU16(b, 0), 65534);
      expect(beS16(b, 0), -2);
      expect(beU32(b, 2), 4294967294);
      expect(beS32(b, 2), -2);
      expect(beU64(b, 6), 1 << 32);
      expect(fourCC(b, 14), 'gpmd');
    });

    test('readBytesAt reads exactly the requested window', () {
      final f = write('e.bin', [10, 11, 12, 13, 14]);
      final raf = f.openSync();
      addTearDown(raf.closeSync);
      expect(readBytesAt(raf, 1, 3), [11, 12, 13]);
      expect(readU32At(raf, 1), (11 << 24) | (12 << 16) | (13 << 8) | 14);
    });
  });
}
