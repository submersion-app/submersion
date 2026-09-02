import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/gpmf_gps_reader.dart';

import '../../../../helpers/media_container_fixtures.dart';

List<int> _s32(int v) => u32(v.toUnsigned(32));

/// One GPMF KLV item: key, type char, struct size, repeat, payload padded
/// to 4 bytes. [type] 0 nests a KLV stream.
List<int> klv(
  String key,
  int type,
  int structSize,
  int repeat,
  List<int> data,
) {
  final padded = [...data, ...List.filled((4 - data.length % 4) % 4, 0)];
  return [...key.codeUnits, type, structSize, ...u16(repeat), ...padded];
}

int t(String c) => c.codeUnitAt(0);

List<int> _gps5Stream({required int fix, required List<List<int>> samples}) {
  final scal = klv('SCAL', t('l'), 4, 5, [
    ..._s32(10000000),
    ..._s32(10000000),
    ..._s32(1000),
    ..._s32(1000),
    ..._s32(100),
  ]);
  final gpsf = klv('GPSF', t('L'), 4, 1, u32(fix));
  final gps5 = klv('GPS5', t('l'), 20, samples.length, [
    for (final s in samples) ...[for (final v in s) ..._s32(v)],
  ]);
  final strm = [
    ...klv('STNM', t('c'), 1, 4, 'GPS '.codeUnits),
    ...scal,
    ...gpsf,
    ...gps5,
  ];
  final wrapped = klv('STRM', 0, 1, strm.length, strm);
  return klv('DEVC', 0, 1, wrapped.length, wrapped);
}

List<int> _gps9Stream(List<({int lat, int lon, int fix})> samples) {
  final type = klv('TYPE', t('c'), 1, 9, 'lllllllSS'.codeUnits);
  final scal = klv('SCAL', t('l'), 4, 9, [
    ..._s32(10000000),
    ..._s32(10000000),
    ..._s32(1000),
    ..._s32(1000),
    ..._s32(100),
    ..._s32(1),
    ..._s32(1000),
    ..._s32(100),
    ..._s32(1),
  ]);
  final gps9 = klv('GPS9', t('?'), 32, samples.length, [
    for (final s in samples) ...[
      ..._s32(s.lat),
      ..._s32(s.lon),
      ..._s32(0),
      ..._s32(0),
      ..._s32(0),
      ..._s32(9000),
      ..._s32(0),
      ...u16(150),
      ...u16(s.fix),
    ],
  ]);
  final strm = [...type, ...scal, ...gps9];
  final wrapped = klv('STRM', 0, 1, strm.length, strm);
  return klv('DEVC', 0, 1, wrapped.length, wrapped);
}

/// GoPro-shaped MP4: ftyp, mdat holding [samples] back to back, moov last
/// with a video track first and a meta/gpmd track whose sample tables point
/// into mdat.
List<int> gpmfMp4(List<List<int>> samples) {
  final ftyp = box('ftyp', 'mp41'.codeUnits);
  final mdatPayload = [for (final s in samples) ...s];
  final mdat = box('mdat', mdatPayload);
  var offset = ftyp.length + 8;
  final offsets = <int>[];
  for (final s in samples) {
    offsets.add(offset);
    offset += s.length;
  }
  final hdlr = fullBox('hdlr', [
    0,
    0,
    0,
    0,
    ...'meta'.codeUnits,
    ...List.filled(12, 0),
    0,
  ]);
  final stsd = fullBox('stsd', [
    ...u32(1),
    ...u32(16),
    ...'gpmd'.codeUnits,
    ...List.filled(8, 0),
  ]);
  final stsz = fullBox('stsz', [
    ...u32(0),
    ...u32(samples.length),
    for (final s in samples) ...u32(s.length),
  ]);
  final stsc = fullBox('stsc', [...u32(1), ...u32(1), ...u32(1), ...u32(1)]);
  final stco = fullBox('stco', [
    ...u32(offsets.length),
    for (final o in offsets) ...u32(o),
  ]);
  final stbl = box('stbl', [...stsd, ...stsz, ...stsc, ...stco]);
  final minf = box('minf', stbl);
  final mdia = box('mdia', [...hdlr, ...minf]);
  final videoTrak = box(
    'trak',
    box(
      'mdia',
      fullBox('hdlr', [0, 0, 0, 0, ...'vide'.codeUnits, ...List.filled(13, 0)]),
    ),
  );
  final moov = box('moov', [
    ...box('mvhd', List.filled(100, 0)),
    ...videoTrak,
    ...box('trak', mdia),
  ]);
  return [...ftyp, ...mdat, ...moov];
}

void main() {
  group('gpsFromGpmfSample', () {
    test('GPS5 with a 3D fix scales lat/lon by SCAL', () {
      final sample = Uint8List.fromList(
        _gps5Stream(
          fix: 3,
          samples: [
            [123456789, -987654321, 5000, 100, 100],
          ],
        ),
      );
      final fix = gpsFromGpmfSample(sample);
      expect(fix?.latitude, closeTo(12.3456789, 1e-7));
      expect(fix?.longitude, closeTo(-98.7654321, 1e-7));
    });

    test('GPS5 without a fix yields null', () {
      final sample = Uint8List.fromList(
        _gps5Stream(
          fix: 0,
          samples: [
            [123456789, -987654321, 0, 0, 0],
          ],
        ),
      );
      expect(gpsFromGpmfSample(sample), isNull);
    });

    test('GPS9 takes the first sample whose own fix field is 2D or better', () {
      final sample = Uint8List.fromList(
        _gps9Stream([
          (lat: 0, lon: 0, fix: 0),
          (lat: 205000000, lon: -872500000, fix: 2),
        ]),
      );
      final fix = gpsFromGpmfSample(sample);
      expect(fix?.latitude, closeTo(20.5, 1e-7));
      expect(fix?.longitude, closeTo(-87.25, 1e-7));
    });

    test('a truncated or garbage stream yields null', () {
      expect(gpsFromGpmfSample(Uint8List.fromList([1, 2, 3])), isNull);
      final full = _gps5Stream(
        fix: 3,
        samples: [
          [1, 2, 3, 4, 5],
        ],
      );
      expect(
        gpsFromGpmfSample(
          Uint8List.fromList(full.sublist(0, full.length ~/ 2)),
        ),
        isNull,
      );
    });
  });

  group('readGpmfGps', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gpmf_');
    });
    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    File write(String name, List<int> bytes) =>
        File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

    test(
      'finds the gpmd track behind a video track and reads the first fix',
      () {
        final f = write(
          'a.mp4',
          gpmfMp4([
            _gps5Stream(
              fix: 3,
              samples: [
                [123456789, -987654321, 0, 0, 0],
              ],
            ),
          ]),
        );
        final fix = readGpmfGps(f);
        expect(fix?.latitude, closeTo(12.3456789, 1e-7));
      },
    );

    test('walks forward past cold-start samples without a fix', () {
      final cold = _gps5Stream(
        fix: 0,
        samples: [
          [0, 0, 0, 0, 0],
        ],
      );
      final warm = _gps5Stream(
        fix: 2,
        samples: [
          [100000000, 200000000, 0, 0, 0],
        ],
      );
      final f = write('b.mp4', gpmfMp4([cold, cold, cold, warm]));
      expect(readGpmfGps(f)?.latitude, closeTo(10.0, 1e-7));
    });

    test('gives up after maxSamples', () {
      final cold = _gps5Stream(
        fix: 0,
        samples: [
          [0, 0, 0, 0, 0],
        ],
      );
      final warm = _gps5Stream(
        fix: 3,
        samples: [
          [100000000, 200000000, 0, 0, 0],
        ],
      );
      final f = write('c.mp4', gpmfMp4([...List.filled(30, cold), warm]));
      expect(readGpmfGps(f, maxSamples: 30), isNull);
      expect(readGpmfGps(f, maxSamples: 31), isNotNull);
    });

    test('returns null without a gpmd track or for a missing file', () {
      final f = write('d.mp4', [
        ...box('ftyp', 'isom'.codeUnits),
        ...box('moov', box('mvhd', [])),
      ]);
      expect(readGpmfGps(f), isNull);
      expect(readGpmfGps(File('${tempDir.path}/none.mp4')), isNull);
    });
  });
}
