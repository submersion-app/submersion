import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/media/data/services/video_capture_time_reader.dart';

import '../../../../helpers/media_container_fixtures.dart';

// Seconds between the QuickTime epoch (1904-01-01) and the Unix epoch.
const _epochShift = 2082844800;

int _qtSeconds(DateTime utc) =>
    utc.millisecondsSinceEpoch ~/ 1000 + _epochShift;

/// mvhd v0 with a 1000 Hz timescale.
List<int> _mvhd(DateTime creation, {Duration duration = Duration.zero}) =>
    fullBox('mvhd', [
      ...u32(_qtSeconds(creation)),
      ...u32(0), // modification_time
      ...u32(1000), // timescale
      ...u32(duration.inMilliseconds),
    ]);

/// moov > meta with one keys/ilst entry, the Apple layout (hdlr first).
List<int> _keysMeta(String key, String value) {
  final hdlr = box('hdlr', [
    ...u32(0),
    ...u32(0),
    ...'mdta'.codeUnits,
    ...List.filled(12, 0),
  ]);
  final keyName = utf8.encode(key);
  final keys = fullBox('keys', [
    ...u32(1),
    ...u32(8 + keyName.length),
    ...'mdta'.codeUnits,
    ...keyName,
  ]);
  final data = box('data', [...u32(1), ...u32(0), ...utf8.encode(value)]);
  final ilst = box('ilst', [...u32(8 + data.length), ...u32(1), ...data]);
  return box('meta', [...hdlr, ...keys, ...ilst]);
}

/// The classic QuickTime user-data text atom: udta > ©day.
List<int> _udtaDay(String text) => box('udta', [
  ...box('©day', [
    ...u16(text.length),
    ...u16(0x15c7), // language: English
    ...ascii.encode(text),
  ]),
]);

/// The iTunes-style form ffmpeg and some cameras write:
/// udta > meta > ilst > ©day > data.
List<int> _udtaIlstDay(String text) {
  final data = box('data', [...u32(1), ...u32(0), ...ascii.encode(text)]);
  final ilst = box('ilst', box('©day', data));
  return box('udta', fullBox('meta', ilst));
}

List<int> _movie(List<int> moovChildren) => [
  ...box('ftyp', 'qt  '.codeUnits),
  ...box('mdat', List<int>.filled(16, 0)),
  ...box('moov', moovChildren),
];

/// Pretends the importing computer sits at UTC-5 regardless of the machine
/// running the test, so the UTC branch is observable even on a UTC CI host.
DateTime _utcMinus5(DateTime utc) => utc.subtract(const Duration(hours: 5));

void main() {
  group('parseQuickTimeDateText', () {
    test('keeps the local digits of a value with an offset', () {
      // An iPhone writes the wall clock where it was recorded plus that
      // place's offset; the digits ARE the dive-site wall clock.
      expect(
        parseQuickTimeDateText('2025-12-27T11:50:49-0500'),
        DateTime.utc(2025, 12, 27, 11, 50, 49),
      );
      expect(
        parseQuickTimeDateText('2025-12-27T11:50:49+05:30'),
        DateTime.utc(2025, 12, 27, 11, 50, 49),
      );
    });

    test('accepts fractional seconds and a space separator', () {
      expect(
        parseQuickTimeDateText('2025-12-27 11:50:49.123+0100'),
        DateTime.utc(2025, 12, 27, 11, 50, 49, 123),
      );
    });

    test('reads a value without a zone as wall clock', () {
      expect(
        parseQuickTimeDateText('2025-12-27T11:50:49'),
        DateTime.utc(2025, 12, 27, 11, 50, 49),
      );
    });

    test('rejects a UTC (Z) value, which carries no local clock', () {
      expect(parseQuickTimeDateText('2025-12-27T16:50:49Z'), isNull);
    });

    test('rejects a year-only or unparseable value', () {
      expect(parseQuickTimeDateText('2025'), isNull);
      expect(parseQuickTimeDateText('yesterday'), isNull);
      expect(parseQuickTimeDateText('2025-13-45T99:99:99'), isNull);
      expect(parseQuickTimeDateText(''), isNull);
    });
  });

  group('resolveMvhdCreationTime', () {
    const clip = Duration(minutes: 3);

    test('converts a UTC value when the mtime marks the recording end', () {
      // A phone at UTC-5 records 11:50:49 local: mvhd holds 16:50:49 UTC and
      // the file closes three minutes later.
      final raw = DateTime.utc(2025, 12, 27, 16, 50, 49);
      expect(
        resolveMvhdCreationTime(
          raw: raw,
          duration: clip,
          modified: raw.add(clip),
          toLocal: _utcMinus5,
        ),
        DateTime.utc(2025, 12, 27, 11, 50, 49),
      );
    });

    test('converts a UTC value when the mtime marks the recording start', () {
      final raw = DateTime.utc(2025, 12, 27, 16, 50, 49);
      expect(
        resolveMvhdCreationTime(
          raw: raw,
          duration: clip,
          modified: raw.add(const Duration(seconds: 20)),
          toLocal: _utcMinus5,
        ),
        DateTime.utc(2025, 12, 27, 11, 50, 49),
      );
    });

    test('keeps a GoPro-style local value whose mtime is local too', () {
      // GoPro writes the local digits 11:50:49. Its mtime is the same local
      // end time, which as an instant is 16:53:49 UTC: not raw + duration.
      final raw = DateTime.utc(2025, 12, 27, 11, 50, 49);
      expect(
        resolveMvhdCreationTime(
          raw: raw,
          duration: clip,
          modified: DateTime.utc(2025, 12, 27, 16, 53, 49),
          toLocal: _utcMinus5,
        ),
        raw,
      );
    });

    test('keeps the local reading when the mtime is a later copy time', () {
      final raw = DateTime.utc(2025, 12, 27, 16, 50, 49);
      expect(
        resolveMvhdCreationTime(
          raw: raw,
          duration: clip,
          modified: DateTime.utc(2026, 1, 9, 8, 12),
          toLocal: _utcMinus5,
        ),
        raw,
      );
    });

    test('keeps the local reading when there is no mtime', () {
      final raw = DateTime.utc(2025, 12, 27, 16, 50, 49);
      expect(
        resolveMvhdCreationTime(
          raw: raw,
          duration: clip,
          modified: null,
          toLocal: _utcMinus5,
        ),
        raw,
      );
    });

    test('a mtime just outside the tolerance is not agreement', () {
      final raw = DateTime.utc(2025, 12, 27, 16, 50, 49);
      expect(
        resolveMvhdCreationTime(
          raw: raw,
          duration: clip,
          modified: raw.add(clip).add(const Duration(minutes: 2)),
          toLocal: _utcMinus5,
        ),
        raw,
      );
    });
  });

  group('readVideoCaptureTime', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('video_time_');
    });
    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    File write(String name, List<int> bytes) =>
        File(p.join(tempDir.path, name))..writeAsBytesSync(bytes);

    final mvhdUtc = DateTime.utc(2025, 12, 27, 16, 50, 49);

    test('prefers the QuickTime creationdate key over mvhd', () {
      final f = write(
        'iphone.mov',
        _movie([
          ..._mvhd(mvhdUtc),
          ..._keysMeta(
            'com.apple.quicktime.creationdate',
            '2025-12-27T11:50:49-0500',
          ),
        ]),
      );
      expect(readVideoCaptureTime(f), DateTime.utc(2025, 12, 27, 11, 50, 49));
    });

    test('uses udta ©day when there is no creationdate', () {
      final f = write(
        'cam.mov',
        _movie([..._mvhd(mvhdUtc), ..._udtaDay('2025-12-27T11:50:49+0100')]),
      );
      expect(readVideoCaptureTime(f), DateTime.utc(2025, 12, 27, 11, 50, 49));
    });

    test('uses the iTunes-style udta meta ilst ©day', () {
      final f = write(
        'ff.mp4',
        _movie([
          ..._mvhd(mvhdUtc),
          ..._udtaIlstDay('2025-12-27T11:50:49+0100'),
        ]),
      );
      expect(readVideoCaptureTime(f), DateTime.utc(2025, 12, 27, 11, 50, 49));
    });

    test('falls through a UTC creationdate to mvhd', () {
      final f = write(
        'z.mov',
        _movie([
          ..._mvhd(mvhdUtc),
          ..._keysMeta(
            'com.apple.quicktime.creationdate',
            '2025-12-27T16:50:49Z',
          ),
        ]),
      );
      // The mtime is "now", which agrees with nothing, so mvhd keeps its
      // local reading.
      expect(readVideoCaptureTime(f), mvhdUtc);
    });

    test('a garbled meta or udta still falls back to mvhd', () {
      final f = write(
        'garbled.mov',
        _movie([
          ..._mvhd(mvhdUtc),
          ...box('meta', [...u32(0xffffffff), ...'keys'.codeUnits, 1, 2]),
          ...box('udta', box('©day', [0xff, 0xff, 0, 0, 1])),
        ]),
      );
      expect(readVideoCaptureTime(f), mvhdUtc);
    });

    test('mvhd alone keeps its local reading when the mtime disagrees', () {
      final f = write('gopro.mp4', _movie(_mvhd(mvhdUtc)));
      expect(readVideoCaptureTime(f), mvhdUtc);
    });

    test('mvhd is read as UTC when the file mtime marks its end', () {
      const clip = Duration(minutes: 3);
      final f = write('phone.mp4', _movie(_mvhd(mvhdUtc, duration: clip)))
        ..setLastModifiedSync(mvhdUtc.add(clip));
      // The real conversion uses this machine's zone, as Windows does for
      // "Media created".
      expect(readVideoCaptureTime(f), asWallClockUtc(mvhdUtc.toLocal()));
    });

    test('returns null for a file with no moov or no usable date', () {
      expect(readVideoCaptureTime(write('junk.mp4', [0, 1, 2, 3])), isNull);
      expect(
        readVideoCaptureTime(
          write(
            'zero.mp4',
            _movie(
              fullBox('mvhd', [...u32(0), ...u32(0), ...u32(1000), ...u32(0)]),
            ),
          ),
        ),
        isNull,
      );
    });
  });
}
