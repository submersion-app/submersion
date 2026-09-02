import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/quicktime_location_reader.dart';

import '../../../../helpers/media_container_fixtures.dart';

const _iso = '+37.3323-122.0312+023.456/';

/// `©xyz` international-text atom inside udta.
List<int> _xyz(String text) => box('©xyz', [
  ...u16(text.length),
  ...u16(0x15c7), // language: English
  ...ascii.encode(text),
]);

List<int> _fullBox(String type, [List<int> payload = const []]) =>
    box(type, [0, 0, 0, 0, ...payload]);

/// moov > meta with keys + ilst. Apple writes meta as a plain box (hdlr at
/// offset 0); ISO files make it a FullBox (version/flags first).
List<int> _meta(String text, {bool asFullBox = false}) {
  final hdlr = box('hdlr', [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    ...'mdta'.codeUnits,
    ...List.filled(12, 0),
  ]);
  final keyName = ascii.encode('com.apple.quicktime.location.ISO6709');
  final keys = _fullBox('keys', [
    ...u32(1),
    ...u32(8 + keyName.length),
    ...'mdta'.codeUnits,
    ...keyName,
  ]);
  final data = box('data', [...u32(1), ...u32(0), ...ascii.encode(text)]);
  final entry = [...u32(8 + data.length), ...u32(1), ...data];
  final ilst = box('ilst', entry);
  final payload = [...hdlr, ...keys, ...ilst];
  return box('meta', asFullBox ? [0, 0, 0, 0, ...payload] : payload);
}

void main() {
  group('parseIso6709', () {
    test('parses the Apple decimal-degree form with altitude', () {
      final fix = parseIso6709(_iso);
      expect(fix?.latitude, closeTo(37.3323, 1e-6));
      expect(fix?.longitude, closeTo(-122.0312, 1e-6));
    });
    test('parses without altitude or trailing slash', () {
      final fix = parseIso6709('-33.8688+151.2093');
      expect(fix?.latitude, closeTo(-33.8688, 1e-6));
      expect(fix?.longitude, closeTo(151.2093, 1e-6));
    });
    test('rejects garbage, (0,0), and out-of-range', () {
      expect(parseIso6709('hello'), isNull);
      expect(parseIso6709('+00.0000+000.0000/'), isNull);
      expect(parseIso6709('+95.0000+010.0000/'), isNull);
      expect(parseIso6709(''), isNull);
    });
  });

  group('readQuickTimeLocation', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qt_loc_');
    });
    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    File write(String name, List<int> bytes) =>
        File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

    test('reads udta > xyz with moov after mdat', () {
      final f = write('a.mov', [
        ...box('ftyp', 'qt  '.codeUnits),
        ...box('mdat', List.filled(64, 0)),
        ...box('moov', [
          ...box('mvhd', List.filled(100, 0)),
          ...box('udta', _xyz(_iso)),
        ]),
      ]);
      final fix = readQuickTimeLocation(f);
      expect(fix?.latitude, closeTo(37.3323, 1e-6));
      expect(fix?.longitude, closeTo(-122.0312, 1e-6));
    });

    test('reads meta > keys/ilst in the Apple (non-FullBox) layout', () {
      final f = write('b.mov', [
        ...box('ftyp', 'qt  '.codeUnits),
        ...box('moov', _meta(_iso)),
      ]);
      expect(readQuickTimeLocation(f)?.longitude, closeTo(-122.0312, 1e-6));
    });

    test('reads meta > keys/ilst in the ISO (FullBox) layout', () {
      final f = write('c.mp4', [
        ...box('ftyp', 'isom'.codeUnits),
        ...box('moov', _meta(_iso, asFullBox: true)),
      ]);
      expect(readQuickTimeLocation(f)?.latitude, closeTo(37.3323, 1e-6));
    });

    test('returns null when neither atom is present or the text is bad', () {
      final none = write('d.mp4', [
        ...box('ftyp', 'isom'.codeUnits),
        ...box('moov', box('mvhd', [])),
      ]);
      expect(readQuickTimeLocation(none), isNull);
      final bad = write('e.mov', [
        ...box('moov', box('udta', _xyz('not a location'))),
      ]);
      expect(readQuickTimeLocation(bad), isNull);
      expect(readQuickTimeLocation(File('${tempDir.path}/none.mov')), isNull);
    });
  });
}
