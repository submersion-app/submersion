import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion_transcoder/submersion_transcoder.dart';

/// An ISO BMFF box: big-endian size, four-character type, payload.
Uint8List box(String type, List<int> payload) {
  final b = BytesBuilder()
    ..add(_u32(8 + payload.length))
    ..add(latin1.encode(type))
    ..add(payload);
  return b.toBytes();
}

List<int> _u32(int v) => [
  (v >> 24) & 0xff,
  (v >> 16) & 0xff,
  (v >> 8) & 0xff,
  v & 0xff,
];

List<int> _u64(int v) => [..._u32(v ~/ 0x100000000), ..._u32(v % 0x100000000)];

final _epoch = DateTime.utc(1904);
int _since1904(DateTime t) => t.difference(_epoch).inSeconds;

Uint8List mvhd(DateTime created, {int version = 0}) => box('mvhd', [
  version, 0, 0, 0, //
  if (version == 0) ...[
    ..._u32(_since1904(created)),
    ..._u32(_since1904(created)),
    ..._u32(600),
    ..._u32(1200),
  ] else ...[
    ..._u64(_since1904(created)),
    ..._u64(_since1904(created)),
    ..._u32(600),
    ..._u64(1200),
  ],
  ...List.filled(80, 0),
]);

Uint8List xyz(String iso) {
  final text = utf8.encode(iso);
  return box('©xyz', [..._u16(text.length), 0x15, 0xc7, ...text]);
}

List<int> _u16(int v) => [(v >> 8) & 0xff, v & 0xff];

List<int> _fixed(double v) => _u32((v * 65536).round() & 0xffffffff);

/// A 3GPP location box, as ffmpeg's MP4 muxer and AVFoundation write it.
Uint8List loci(double lat, double lon, double alt) => box('loci', [
  0, 0, 0, 0, // version, flags
  0x15, 0xc7, // language
  0, // empty name
  0, // role
  ..._fixed(lon),
  ..._fixed(lat),
  ..._fixed(alt),
  0, // body
  0, // notes
]);

/// A track header (tkhd) or media header (mdhd), version 0.
Uint8List trackHeader(String type, DateTime t) => box(type, [
  0, 0, 0, 0, //
  ..._u32(_since1904(t)),
  ..._u32(_since1904(t)),
  ...List.filled(type == 'tkhd' ? 76 : 12, 0),
]);

const identityMatrix = [0x10000, 0, 0, 0, 0x10000, 0, 0, 0, 0x40000000];
const rotate90Matrix = [0, 0x10000, 0, -0x10000, 0, 0, 0, 0, 0x40000000];

/// A trak with a version 0 track header carrying [matrix], whose media
/// handler is [handler] ('vide' or 'soun').
Uint8List trak(List<int> matrix, {String handler = 'vide'}) {
  final tkhd = ByteData(84)..setUint32(12, 1);
  for (var i = 0; i < 9; i++) {
    tkhd.setInt32(40 + i * 4, matrix[i]);
  }
  final hdlr = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    ...latin1.encode(handler),
    ...List.filled(13, 0),
  ];
  return box('trak', [
    ...box('tkhd', tkhd.buffer.asUint8List()),
    ...box('mdia', box('hdlr', hdlr)),
  ]);
}

DateTime trackHeaderDate(Uint8List file, String type) {
  final at = _indexOf(file, latin1.encode(type));
  final seconds = ByteData.sublistView(file).getUint32(at + 8);
  return _epoch.add(Duration(seconds: seconds));
}

int _indexOf(Uint8List hay, List<int> needle) {
  for (var i = 0; i + needle.length <= hay.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length && ok; j++) {
      ok = hay[i + j] == needle[j];
    }
    if (ok) return i;
  }
  return -1;
}

/// A QuickTime metadata box (no version/flags, as iPhone movies write it).
Uint8List mdta(Map<String, String> items, {bool fullBox = false}) {
  final keys = BytesBuilder()
    ..add([0, 0, 0, 0])
    ..add(_u32(items.length));
  for (final k in items.keys) {
    final name = utf8.encode(k);
    keys
      ..add(_u32(8 + name.length))
      ..add(latin1.encode('mdta'))
      ..add(name);
  }
  final ilst = BytesBuilder();
  var i = 1;
  for (final v in items.values) {
    final data = box('data', [..._u32(1), ..._u32(0), ...utf8.encode(v)]);
    ilst
      ..add(_u32(8 + data.length))
      ..add(_u32(i++))
      ..add(data);
  }
  return box('meta', [
    if (fullBox) ...[0, 0, 0, 0],
    ...box('hdlr', [
      ...List.filled(8, 0),
      ...latin1.encode('mdta'),
      ...List.filled(13, 0),
    ]),
    ...box('keys', keys.toBytes()),
    ...box('ilst', ilst.toBytes()),
  ]);
}

Uint8List movie(List<Uint8List> moovChildren, {bool moovLast = false}) {
  final ftyp = box('ftyp', latin1.encode('isom\u0000\u0000\u0002\u0000isom'));
  final mdat = box('mdat', List.filled(64, 7));
  final moov = box('moov', [for (final c in moovChildren) ...c]);
  return Uint8List.fromList([
    ...ftyp,
    if (!moovLast) ...moov,
    ...mdat,
    if (moovLast) ...moov,
  ]);
}

/// Issue #3521: the recording date and place a corrected copy keeps.
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mp4_info'));
  tearDown(() => dir.delete(recursive: true));

  Future<File> write(Uint8List bytes) async {
    final f = File(p.join(dir.path, 'clip.mp4'));
    await f.writeAsBytes(bytes);
    return f;
  }

  final date = DateTime.utc(2026, 5, 1, 10);

  test('reads the movie header date and an Android-style location', () async {
    final f = await write(
      movie([
        mvhd(date),
        box('udta', xyz('+20.5000-087.0000/')),
      ], moovLast: true),
    );
    final info = await readMp4RecordingInfo(f);
    expect(info.created, date);
    expect(info.location, '+20.5000-087.0000/');
  });

  test('reads a 3GPP loci location as ISO 6709', () async {
    final f = await write(
      movie([mvhd(date), box('udta', loci(20.5, -87.0, 0))]),
    );
    expect(
      (await readMp4RecordingInfo(f)).location,
      '+20.5000-087.0000+000.000/',
    );
  });

  test('reads a loci location whose name is UTF-16', () async {
    final name = [
      0xfe,
      0xff,
      0x00,
      0x52,
      0x00,
      0x65,
      0x00,
      0x65,
      0x00,
      0x66,
      0x00,
      0x00,
    ];
    final fixed = ByteData(12)
      ..setInt32(0, (-87.0 * 65536).round())
      ..setInt32(4, (20.5 * 65536).round())
      ..setInt32(8, 0);
    final box16 = box('loci', [
      0,
      0,
      0,
      0,
      0x15,
      0xc7,
      ...name,
      0,
      ...fixed.buffer.asUint8List(),
      0,
      0,
    ]);
    final f = await write(movie([mvhd(date), box('udta', box16)]));
    expect(
      (await readMp4RecordingInfo(f)).location,
      '+20.5000-087.0000+000.000/',
    );
  });

  test('the recording info carries the video track matrix', () async {
    final f = await write(movie([mvhd(date), trak(rotate90Matrix)]));
    expect((await readMp4RecordingInfo(f)).videoMatrix, rotate90Matrix);
  });

  test('reads a version 1 movie header', () async {
    final f = await write(movie([mvhd(date, version: 1)]));
    expect((await readMp4RecordingInfo(f)).created, date);
  });

  test('prefers QuickTime creationdate and location keys (iPhone)', () async {
    final f = await write(
      movie([
        mvhd(DateTime.utc(2026, 5, 2)),
        mdta({
          'com.apple.quicktime.location.ISO6709': '+12.3456-045.6789+001.000/',
          'com.apple.quicktime.creationdate': '2026-05-01T12:00:00+0200',
        }),
      ]),
    );
    final info = await readMp4RecordingInfo(f);
    expect(info.created, date);
    expect(info.location, '+12.3456-045.6789+001.000/');
  });

  test('reads metadata in an ISO full-box meta under udta', () async {
    final f = await write(
      movie([
        mvhd(date),
        box(
          'udta',
          mdta({
            'com.apple.quicktime.location.ISO6709': '+1.0000+002.0000/',
          }, fullBox: true),
        ),
      ]),
    );
    expect((await readMp4RecordingInfo(f)).location, '+1.0000+002.0000/');
  });

  test('a zero movie header date is no date', () async {
    final f = await write(movie([mvhd(_epoch)]));
    expect((await readMp4RecordingInfo(f)).created, isNull);
  });

  test('a file that is not a movie gives nothing and does not throw', () async {
    final f = await write(Uint8List.fromList(utf8.encode('not a movie')));
    final info = await readMp4RecordingInfo(f);
    expect(info.created, isNull);
    expect(info.location, isNull);
  });

  test('stamps the movie header creation time, both versions', () async {
    for (final version in [0, 1]) {
      final f = await write(
        movie([mvhd(DateTime.utc(2030), version: version)], moovLast: true),
      );
      final before = await f.length();
      await stampMp4CreationTime(f, date);
      expect((await readMp4RecordingInfo(f)).created, date);
      expect(await f.length(), before);
    }
  });

  test('stamps every track and media header too', () async {
    final made = DateTime.utc(2030);
    final f = await write(
      movie([
        mvhd(made),
        box('trak', [
          ...trackHeader('tkhd', made),
          ...box('mdia', trackHeader('mdhd', made)),
        ]),
      ]),
    );
    await stampMp4CreationTime(f, date);
    final bytes = await f.readAsBytes();
    expect(trackHeaderDate(bytes, 'tkhd'), date);
    expect(trackHeaderDate(bytes, 'mdhd'), date);
  });

  group('video matrix', () {
    test('reads the video track matrix, not the sound one', () async {
      final f = await write(
        movie([
          mvhd(date),
          trak(identityMatrix, handler: 'soun'),
          trak(rotate90Matrix),
        ]),
      );
      expect(await readMp4VideoMatrix(f), rotate90Matrix);
    });

    test('writes the video track matrix in place', () async {
      final f = await write(
        movie([mvhd(date), trak(identityMatrix)], moovLast: true),
      );
      final before = await f.length();
      expect(await setMp4VideoMatrix(f, rotate90Matrix), isTrue);
      expect(await readMp4VideoMatrix(f), rotate90Matrix);
      expect(await f.length(), before);
    });

    test('a file with no video track gives no matrix', () async {
      final f = await write(movie([mvhd(date)]));
      expect(await readMp4VideoMatrix(f), isNull);
      expect(await setMp4VideoMatrix(f, rotate90Matrix), isFalse);
    });
  });

  group('addMp4Location', () {
    test('adds a location to a movie whose moov is last', () async {
      final bytes = movie([mvhd(date)], moovLast: true);
      final f = await write(bytes);
      expect(await addMp4Location(f, '+20.5000-087.0000+000.000/'), isTrue);
      expect(
        (await readMp4RecordingInfo(f)).location,
        '+20.5000-087.0000+000.000/',
      );
      // Everything before the moov (the media data) is untouched.
      final after = await f.readAsBytes();
      final moovAt = bytes.length - (box('moov', mvhd(date))).length;
      expect(after.sublist(0, moovAt), bytes.sublist(0, moovAt));
    });

    test('goes inside an existing udta', () async {
      final f = await write(
        movie([
          mvhd(date),
          box('udta', box('©too', [0, 3, 0, 0, 0x61, 0x62, 0x63])),
        ], moovLast: true),
      );
      expect(await addMp4Location(f, '-12.5000+130.2500/'), isTrue);
      expect(
        (await readMp4RecordingInfo(f)).location,
        '-12.5000+130.2500+000.000/',
      );
    });

    test('leaves a movie whose moov is not last alone', () async {
      final bytes = movie([mvhd(date)]);
      final f = await write(bytes);
      expect(await addMp4Location(f, '+20.5000-087.0000/'), isFalse);
      expect(await f.readAsBytes(), bytes);
    });

    test('an unreadable location changes nothing', () async {
      final bytes = movie([mvhd(date)], moovLast: true);
      final f = await write(bytes);
      expect(await addMp4Location(f, 'somewhere'), isFalse);
      expect(await f.readAsBytes(), bytes);
    });
  });

  test('stamping a file with no movie header changes nothing', () async {
    final bytes = Uint8List.fromList(utf8.encode('plain bytes'));
    final f = await write(bytes);
    await stampMp4CreationTime(f, date);
    expect(await f.readAsBytes(), bytes);
  });
}
